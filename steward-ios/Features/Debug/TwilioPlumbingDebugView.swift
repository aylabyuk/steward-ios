import SwiftUI
import StewardCore

#if DEBUG && canImport(FirebaseFirestore)
import FirebaseFirestore

/// DEBUG-only acceptance screen for the Phase 1 Twilio plumbing
/// (issueSpeakerSession + sendSpeakerInvitation + TwilioChatClient).
///
/// Usage flow (matches the plan's Phase 1.e gate):
///   1. From the schedule, open the avatar menu and tap "Twilio plumbing
///      (debug)".
///   2. Tap **Connect** → expect `status: ready` (or `partial` until the
///      Twilio SDK is added) and the bishop's `uid:…` identity printed.
///   3. Paste a `conversationSid` from a web-minted invitation (the
///      Firebase emulator UI's `wards/{wardId}/speakerInvitations`
///      collection has them) and tap **Fetch** → message count + latest
///      body should print.
///
/// Removed entirely from non-DEBUG builds via the file-level guard.
struct TwilioPlumbingDebugView: View {
    let wardId: String
    @Environment(TwilioChatClient.self) private var twilio
    @State private var conversationSid: String = ""
    @State private var fetchedSummary: String?
    @State private var fetchError: String?
    @State private var fetching: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                AppBarHeader(
                    eyebrow: "Debug",
                    title: "Twilio plumbing",
                    description: "Phase 1 acceptance check — connect, then fetch a conversation by SID."
                )

                statusCard
                    .padding(.horizontal, Spacing.s4)

                connectActions
                    .padding(.horizontal, Spacing.s4)

                fetchSection
                    .padding(.horizontal, Spacing.s4)

                Spacer().frame(height: Spacing.s12)
            }
        }
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle("Twilio plumbing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            row("Ward ID", wardId)
            row("Status", statusLabel)
            row("Identity", twilio.identity ?? "—")
            if let lastError = twilio.lastError {
                Text(lastError)
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private var connectActions: some View {
        VStack(spacing: Spacing.s2) {
            Button {
                Task { await twilio.connect(wardId: wardId) }
            } label: {
                Label("Connect", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bordeaux)
            .controlSize(.large)
            .disabled(connecting)

            Button {
                twilio.disconnect()
                fetchedSummary = nil
                fetchError = nil
            } label: {
                Text("Disconnect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.walnut2)
            .controlSize(.large)
        }
    }

    private var fetchSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Fetch a conversation by SID")
                .font(.bodyEmphasis)
                .foregroundStyle(Color.walnut)

            TextField("CHxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", text: $conversationSid)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))

            Button {
                Task { await fetchConversation() }
            } label: {
                Label("Fetch", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.walnut)
            .controlSize(.large)
            .disabled(conversationSid.isEmpty || fetching || twilio.status != .ready)

            if let fetchedSummary {
                Text(fetchedSummary)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color.walnut)
                    .padding(Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.parchment2)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.default))
            }
            if let fetchError {
                Text(fetchError)
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var connecting: Bool {
        switch twilio.status {
        case .connecting: return true
        default:          return false
        }
    }

    private var statusLabel: String {
        switch twilio.status {
        case .idle:                       return "idle"
        case .connecting:                 return "connecting…"
        case .partial:                    return "token minted (Twilio SDK not yet added)"
        case .ready:                      return "ready"
        case .error(let message):         return "error — \(message)"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.brassDeep)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.walnut)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func fetchConversation() async {
        fetching = true
        fetchError = nil
        fetchedSummary = nil
        defer { fetching = false }
        #if canImport(TwilioConversationsClient)
        do {
            let conversation = try await twilio.conversation(withSid: conversationSid)
            let count = try await Self.messageCount(of: conversation)
            let lastBody = try await Self.lastMessageBody(of: conversation)
            fetchedSummary = """
            sid: \(conversationSid)
            messages: \(count)
            last body: \(lastBody ?? "—")
            """
        } catch {
            fetchError = error.localizedDescription
        }
        #else
        fetchError = "Twilio Conversations iOS SDK not yet added — see plan Phase 1a."
        #endif
    }

    #if canImport(TwilioConversationsClient)
    private static func messageCount(of conversation: TCHConversation) async throws -> UInt {
        try await withCheckedThrowingContinuation { continuation in
            conversation.getMessagesCount { result, count in
                if result.isSuccessful {
                    continuation.resume(returning: count)
                } else {
                    continuation.resume(throwing: TwilioChatClientError.conversationFetchFailed(
                        sid: conversation.sid ?? "?",
                        message: result.error?.localizedDescription ?? "unknown"
                    ))
                }
            }
        }
    }

    private static func lastMessageBody(of conversation: TCHConversation) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            conversation.getLastMessages(withCount: 1) { result, messages in
                if result.isSuccessful {
                    continuation.resume(returning: messages?.last?.body)
                } else {
                    continuation.resume(throwing: TwilioChatClientError.conversationFetchFailed(
                        sid: conversation.sid ?? "?",
                        message: result.error?.localizedDescription ?? "unknown"
                    ))
                }
            }
        }
    }
    #endif
}

#if canImport(TwilioConversationsClient)
@preconcurrency import TwilioConversationsClient
#endif
#endif
