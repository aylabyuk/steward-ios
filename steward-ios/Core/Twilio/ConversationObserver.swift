import Foundation
import StewardCore
@preconcurrency import TwilioConversationsClient

/// Per-conversation observer that mirrors the web's `useConversation`
/// hook at `src/features/invitations/hooks/useConversation.ts:44-141`.
/// Owns the live `TCHConversation`, hosts a Twilio delegate, and
/// publishes everything the chat-sheet view needs to render.
///
/// `@MainActor @Observable` so SwiftUI re-renders on every property
/// change. The Twilio SDK fires delegate callbacks on the main
/// thread by contract, so updating from the delegate methods is safe.
@MainActor
@Observable
final class ConversationObserver: NSObject {
    let conversation: TCHConversation
    /// The current viewer's Twilio identity (`uid:{firebaseUid}` for
    /// bishopric). Used to compute "mine" on each message and to
    /// exclude self from the read horizon + typing aggregation.
    let identity: String

    private(set) var loading: Bool = true
    private(set) var error: Error?
    private(set) var messages: [ChatMessage] = []
    /// Twilio identities currently typing, excluding self.
    private(set) var typingIdentities: Set<String> = []
    /// Snapshotted at init — pinned so the divider doesn't drift as
    /// new messages arrive. nil = no unread divider.
    private(set) var firstUnreadIndex: Int?
    /// Highest message index any other participant has read up to.
    /// Drives the "Read" receipt under the viewer's last bubble.
    private(set) var readHorizonIndex: Int?
    /// Author map keyed by Twilio identity. Seeded from the invitation
    /// doc's `bishopricParticipants` snapshot + speaker name; Twilio
    /// participant attributes overlay on top.
    private(set) var authors: [String: AuthorInfo] = [:]

    init(
        conversation: TCHConversation,
        identity: String,
        invitation: SpeakerInvitation
    ) {
        self.conversation = conversation
        self.identity = identity
        super.init()
        seedAuthors(from: invitation)
        conversation.delegate = self
        Task { await loadInitialState() }
    }

    deinit {
        // Only clear if we're still the delegate — another observer
        // may have replaced us.
    }

    /// Detach the delegate cleanly when the chat sheet closes. Called
    /// explicitly by the chat view's `onDisappear` since SwiftUI's
    /// destruction timing isn't deterministic.
    nonisolated func detach() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.conversation.delegate === self {
                self.conversation.delegate = nil
            }
        }
    }

    // MARK: - Initial load

    private func seedAuthors(from invitation: SpeakerInvitation) {
        var seed: [String: AuthorInfo] = [:]
        for participant in invitation.bishopricParticipants {
            seed["uid:\(participant.uid)"] = AuthorInfo(
                displayName: participant.displayName,
                role: participant.role,
                email: participant.email
            )
        }
        // The speaker identity is `speaker:{invitationId}` — we don't
        // have the invitation id here, but the wrapping observer
        // initializer can override via `setSpeakerAuthor(...)` if it
        // wants to set a more specific identity. For now, seed both
        // common shapes so unknown speaker identities still resolve.
        seed["speaker:?"] = AuthorInfo(displayName: invitation.speakerName, role: "speaker")
        self.authors = seed
    }

    /// Set the precise speaker identity → name mapping once the
    /// invitation id is known. The chat view calls this with
    /// `speaker:{invitationId}` after fetching the conversation.
    func setSpeakerAuthor(identity: String, displayName: String) {
        var next = authors
        next[identity] = AuthorInfo(displayName: displayName, role: "speaker")
        authors = next
    }

    private func loadInitialState() async {
        do {
            let participants = try await fetchParticipants()
            mergeParticipantAuthors(participants)
            firstUnreadIndex = computeFirstUnreadIndex(participants: participants)
            readHorizonIndex = computeReadHorizon(participants: participants)
            let recent = try await fetchRecentMessages(count: 50)
            // Merge — never overwrite. The `messageAdded` delegate can
            // race with the bulk fetch during initial sync; a naïve
            // assignment of an empty `recent` would wipe out cached
            // messages the delegate already pushed. Pinned by
            // `ChatMessageMergeTests`.
            messages = messages.merged(with: recent)
            loading = false
        } catch {
            self.error = error
            loading = false
        }
    }

    /// Re-fetch when this conversation's local Twilio cache transitions
    /// to fully synced. The initial bulk fetch in `loadInitialState`
    /// can land before the cache has the messages, returning empty;
    /// once the SDK reports `.all`, the cached history is reachable.
    /// Merge keeps anything the delegate already pushed.
    private func handleConversationFullySynced() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let recent = try await self.fetchRecentMessages(count: 50)
                self.messages = self.messages.merged(with: recent)
            } catch {
                // Best-effort: leave whatever messageAdded has pushed
                // in place. Don't surface the refetch error since the
                // primary load already flipped `loading` to false.
            }
        }
    }

    private func fetchParticipants() async throws -> [TCHParticipant] {
        // `participants` is a synchronous accessor on TCHConversation
        // (the SDK lazy-loads on attribute access). Wrapping in a Task
        // keeps the call site uniformly async with the rest of the
        // load sequence.
        return conversation.participants()
    }

    private func fetchRecentMessages(count: UInt) async throws -> [ChatMessage] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ChatMessage], Error>) in
            conversation.getLastMessages(withCount: count) { result, list in
                if result.isSuccessful {
                    let messages = (list ?? []).map(toChatMessage(_:))
                    continuation.resume(returning: messages)
                } else {
                    continuation.resume(throwing: result.error ?? makeError("messages fetch failed"))
                }
            }
        }
    }

    private func mergeParticipantAuthors(_ participants: [TCHParticipant]) {
        var next = authors
        for participant in participants {
            guard let identity = participant.identity else { continue }
            guard let info = parseAuthorInfo(participant) else { continue }
            next[identity] = info
        }
        authors = next
    }

    private func computeFirstUnreadIndex(participants: [TCHParticipant]) -> Int? {
        // Find self's lastReadMessageIndex, and if there are unread
        // messages, return lastRead + 1. Mirrors the web's
        // useFirstUnreadIndex.
        guard let me = participants.first(where: { $0.identity == identity }) else { return nil }
        guard let lastRead = me.lastReadMessageIndex?.intValue else {
            // No reads yet — first unread is index 0 if there's at
            // least one message
            return messages.isEmpty ? nil : 0
        }
        // The conversation's max message index isn't directly
        // exposed; rely on `messages` length to bound the divider.
        let nextIndex = lastRead + 1
        return nextIndex
    }

    private func computeReadHorizon(participants: [TCHParticipant]) -> Int? {
        let others = participants.filter { $0.identity != identity }
        let indices = others.compactMap { $0.lastReadMessageIndex?.intValue }
        return indices.max()
    }

    // MARK: - Send / mutate

    func send(body: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = TCHMessageOptions().withBody(body)
            conversation.sendMessage(with: options) { result, _ in
                if result.isSuccessful {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: result.error ?? makeError("sendMessage failed"))
                }
            }
        }
    }

    /// Notify Twilio the viewer has caught up. Mirrors
    /// `BishopInvitationChat.tsx:106-109`.
    func setAllMessagesRead() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            conversation.setAllMessagesReadWithCompletion { _, _ in
                continuation.resume()
            }
        }
    }

    /// Best-effort typing notification. Twilio rate-limits these
    /// internally so safe to call on every keystroke.
    func notifyTyping() {
        conversation.typing()
    }

    func remove(messageSid: String) async throws {
        let message = try await findMessage(withSid: messageSid)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // `removeMessage(_:completion:)` lives on TCHConversation,
            // not on the message itself.
            conversation.remove(message) { result in
                if result.isSuccessful {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: result.error ?? makeError("remove failed"))
                }
            }
        }
    }

    func updateBody(messageSid: String, body: String) async throws {
        let message = try await findMessage(withSid: messageSid)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            message.updateBody(body) { result in
                if result.isSuccessful {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: result.error ?? makeError("updateBody failed"))
                }
            }
        }
    }

    private func findMessage(withSid sid: String) async throws -> TCHMessage {
        // Walk the last 200 — the recent window the chat-sheet supports
        // editing in is much smaller, but the lookup buffer can be
        // generous since Twilio caches.
        let messages = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[TCHMessage], Error>) in
            conversation.getLastMessages(withCount: 200) { result, list in
                if result.isSuccessful {
                    continuation.resume(returning: list ?? [])
                } else {
                    continuation.resume(throwing: result.error ?? makeError("getLastMessages failed"))
                }
            }
        }
        if let match = messages.first(where: { $0.sid == sid }) {
            return match
        }
        throw makeError("message \(sid) not found")
    }
}

// MARK: - TCHConversationDelegate

extension ConversationObserver: TCHConversationDelegate {

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        messageAdded message: TCHMessage
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let chat = toChatMessage(message)
            // Keep the array sorted by index (Twilio guarantees
            // monotonic, but defensive against out-of-order callbacks).
            var next = self.messages
            if let existingIndex = next.firstIndex(where: { $0.sid == chat.sid }) {
                next[existingIndex] = chat
            } else {
                next.append(chat)
            }
            next.sort { $0.index < $1.index }
            self.messages = next
        }
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        message: TCHMessage,
        updated: TCHMessageUpdate
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let chat = toChatMessage(message)
            self.messages = self.messages.map { $0.sid == chat.sid ? chat : $0 }
        }
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        synchronizationStatusUpdated status: TCHConversationSynchronizationStatus
    ) {
        // Twilio's per-conversation sync runs through .none →
        // .identifier → .metadata → .all. `getLastMessages` returns
        // real history only at .all; before that, it can resolve with
        // whatever fragment is locally cached (often empty on first
        // open). Re-fetch when we hit .all so the thread isn't stuck
        // on the empty/loading state.
        guard status == .all else { return }
        Task { @MainActor [weak self] in
            self?.handleConversationFullySynced()
        }
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        messageDeleted message: TCHMessage
    ) {
        let sid = message.sid
        Task { @MainActor [weak self] in
            guard let self, let sid else { return }
            self.messages = self.messages.filter { $0.sid != sid }
        }
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        participantJoined participant: TCHParticipant
    ) {
        handleParticipantUpdate(participant)
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        conversation: TCHConversation,
        participant: TCHParticipant,
        updated: TCHParticipantUpdate
    ) {
        handleParticipantUpdate(participant)
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        typingStartedOn conversation: TCHConversation,
        participant: TCHParticipant
    ) {
        let identity = participant.identity
        Task { @MainActor [weak self] in
            guard let self, let identity, identity != self.identity else { return }
            self.typingIdentities.insert(identity)
        }
    }

    nonisolated func conversationsClient(
        _ client: TwilioConversationsClient,
        typingEndedOn conversation: TCHConversation,
        participant: TCHParticipant
    ) {
        let identity = participant.identity
        Task { @MainActor [weak self] in
            guard let self, let identity else { return }
            self.typingIdentities.remove(identity)
        }
    }

    nonisolated private func handleParticipantUpdate(_ participant: TCHParticipant) {
        let identity = participant.identity
        let info = parseAuthorInfo(participant)
        let lastRead = participant.lastReadMessageIndex?.intValue
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let identity, let info {
                var next = self.authors
                next[identity] = info
                self.authors = next
            }
            // Update the read horizon from any participant change.
            if let identity, identity != self.identity, let lastRead {
                self.readHorizonIndex = max(self.readHorizonIndex ?? 0, lastRead)
            }
        }
    }
}

// MARK: - Twilio adapter helpers

private nonisolated func toChatMessage(_ message: TCHMessage) -> ChatMessage {
    let sid = message.sid ?? ""
    let index = message.index?.intValue ?? 0
    let author = message.author ?? ""
    let body = message.body ?? ""
    let dateCreated = message.dateCreatedAsDate
    let dateUpdated = message.dateUpdatedAsDate
    let attributes: ChatMessage.Attributes? = {
        guard let raw = message.attributes()?.dictionary as? [String: Any] else { return nil }
        return ChatMessage.Attributes.parse(raw)
    }()
    return ChatMessage(
        sid: sid,
        index: index,
        author: author,
        body: body,
        dateCreated: dateCreated,
        dateUpdated: dateUpdated,
        attributes: attributes
    )
}

private nonisolated func parseAuthorInfo(_ participant: TCHParticipant) -> AuthorInfo? {
    guard let raw = participant.attributes()?.dictionary as? [String: Any] else { return nil }
    guard let displayName = raw["displayName"] as? String else { return nil }
    let role = raw["role"] as? String
    let email = raw["email"] as? String
    return AuthorInfo(displayName: displayName, role: role, email: email)
}

private nonisolated func makeError(_ message: String) -> Error {
    NSError(
        domain: "ConversationObserver",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: message]
    )
}
