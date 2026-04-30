import Foundation
import StewardCore
@preconcurrency import TwilioConversationsClient

/// Owns the Twilio Conversations client for the bishopric session. Mirrors
/// the web's `TwilioChatProvider` at
/// `src/features/invitations/TwilioChatProvider.tsx:39-104` —
/// lazy `connect()`, automatic token refresh, idempotent.
///
/// Identity scheme matches the web exactly: the bishop is `uid:{firebaseUid}`.
/// The `issueSpeakerSession` Cloud Function infers that from the bishop's
/// Firebase auth token; iOS just sends `{ wardId }`.
@MainActor
@Observable
final class TwilioChatClient {
    enum Status: Equatable, Sendable {
        case idle
        case connecting
        case ready
        case error(message: String)
    }

    private(set) var status: Status = .idle
    private(set) var identity: String?
    private(set) var lastError: String?

    /// Captured on `connect()` so the `tokenAboutToExpire` delegate can
    /// re-issue with the same scope.
    private var connectOptions: (wardId: String, invitationId: String?)?

    private var client: TwilioConversationsClient?
    private var delegate: TwilioChatDelegate?

    init() {}

    /// Lazily connect. Idempotent on repeat calls — if we're already
    /// connected, the second call is a no-op (matches the web's
    /// `if (clientRef.current) return;` short-circuit).
    func connect(wardId: String, invitationId: String? = nil) async {
        switch status {
        case .ready, .connecting:
            return
        case .idle, .error:
            break
        }
        connectOptions = (wardId, invitationId)
        status = .connecting
        lastError = nil
        do {
            let session = try await FunctionsClient.issueSpeakerSession(
                wardId: wardId,
                invitationId: invitationId
            )
            identity = session.identity
            try await bringClientUp(token: session.twilioToken)
            status = .ready
        } catch {
            lastError = error.localizedDescription
            status = .error(message: error.localizedDescription)
        }
    }

    /// Tear the client down on sign-out so listeners stop firing and
    /// the next sign-in can reconnect from scratch. Mirrors
    /// `TwilioChatProvider.disconnect`.
    func disconnect() {
        client?.shutdown()
        client = nil
        delegate = nil
        identity = nil
        connectOptions = nil
        status = .idle
        lastError = nil
    }

    /// Fetch a conversation by SID. Used by the chat sheet once it knows
    /// which `speakerInvitations/{id}.conversationSid` it's rendering.
    func conversation(withSid sid: String) async throws -> TCHConversation {
        guard let client else {
            throw TwilioChatClientError.notConnected
        }
        return try await withCheckedThrowingContinuation { continuation in
            client.conversation(withSidOrUniqueName: sid) { result, conversation in
                if let conversation, result.isSuccessful {
                    continuation.resume(returning: conversation)
                } else {
                    continuation.resume(throwing: TwilioChatClientError.conversationFetchFailed(
                        sid: sid,
                        message: result.error?.localizedDescription ?? "unknown error"
                    ))
                }
            }
        }
    }

    /// Build a ConversationObserver bound to the live conversation.
    /// The observer takes over the conversation's `delegate` slot and
    /// publishes message / participant / typing updates as
    /// `@Observable` properties for the chat sheet.
    func observer(
        forSid sid: String,
        invitation: SpeakerInvitation
    ) async throws -> ConversationObserver {
        guard let identity else {
            throw TwilioChatClientError.notConnected
        }
        let conversation = try await conversation(withSid: sid)
        return ConversationObserver(
            conversation: conversation,
            identity: identity,
            invitation: invitation
        )
    }

    /// Mint the SDK client and install the delegate that drives our
    /// status state machine + token refresh callback.
    private func bringClientUp(token: String) async throws {
        let delegate = TwilioChatDelegate { [weak self] event in
            Task { @MainActor in
                await self?.handleDelegateEvent(event)
            }
        }
        self.delegate = delegate
        let client = try await Self.startClient(token: token, delegate: delegate)
        self.client = client
    }

    private static func startClient(
        token: String,
        delegate: TwilioConversationsClientDelegate
    ) async throws -> TwilioConversationsClient {
        try await withCheckedThrowingContinuation { continuation in
            TwilioConversationsClient.conversationsClient(
                withToken: token,
                properties: nil,
                delegate: delegate
            ) { result, client in
                if let client, result.isSuccessful {
                    continuation.resume(returning: client)
                } else {
                    continuation.resume(throwing: TwilioChatClientError.connectFailed(
                        message: result.error?.localizedDescription ?? "unknown error"
                    ))
                }
            }
        }
    }

    private func handleDelegateEvent(_ event: TwilioChatDelegate.Event) async {
        switch event {
        case .tokenWillExpire:
            await refreshToken()
        case .tokenExpired:
            status = .error(message: "Twilio session expired. Sign in again.")
        case .clientFailed(let message):
            status = .error(message: message)
        case .synchronizationCompleted:
            // The SDK reports synchronization milestones for individual
            // conversations; the top-level client status flips to
            // .ready right after `startClient` returns, so we don't
            // gate on this.
            break
        }
    }

    private func refreshToken() async {
        guard let connectOptions else { return }
        do {
            let session = try await FunctionsClient.issueSpeakerSession(
                wardId: connectOptions.wardId,
                invitationId: connectOptions.invitationId
            )
            try await updateClientToken(session.twilioToken)
        } catch {
            status = .error(message: "Token refresh failed: \(error.localizedDescription)")
        }
    }

    private func updateClientToken(_ token: String) async throws {
        guard let client else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.updateToken(token) { result in
                if result.isSuccessful {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TwilioChatClientError.tokenUpdateFailed(
                        message: result.error?.localizedDescription ?? "unknown error"
                    ))
                }
            }
        }
    }
}

enum TwilioChatClientError: Error, LocalizedError {
    case notConnected
    case connectFailed(message: String)
    case tokenUpdateFailed(message: String)
    case conversationFetchFailed(sid: String, message: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:                                     "Not connected to Twilio."
        case .connectFailed(let message):                       "Couldn't connect to Twilio — \(message)"
        case .tokenUpdateFailed(let message):                   "Couldn't refresh the Twilio token — \(message)"
        case .conversationFetchFailed(let sid, let message):    "Couldn't fetch conversation \(sid) — \(message)"
        }
    }
}

/// Erases the Twilio delegate's many callbacks down to a coarse Event
/// stream the @Observable client can react to on the main actor.
private final class TwilioChatDelegate: NSObject, TwilioConversationsClientDelegate, @unchecked Sendable {
    enum Event {
        case tokenWillExpire
        case tokenExpired
        case clientFailed(message: String)
        case synchronizationCompleted
    }

    private let onEvent: @Sendable (Event) -> Void

    init(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
    }

    func conversationsClientTokenWillExpire(_ client: TwilioConversationsClient) {
        onEvent(.tokenWillExpire)
    }

    func conversationsClientTokenExpired(_ client: TwilioConversationsClient) {
        onEvent(.tokenExpired)
    }

    func conversationsClient(
        _ client: TwilioConversationsClient,
        synchronizationStatusUpdated status: TCHClientSynchronizationStatus
    ) {
        if status == .completed {
            onEvent(.synchronizationCompleted)
        } else if status == .failed {
            onEvent(.clientFailed(message: "Twilio synchronization failed"))
        }
    }
}
