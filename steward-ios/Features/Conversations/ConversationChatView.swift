import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// Composed chat pane: status banner + thread + typing + composer.
/// Mirrors the web's `BishopInvitationChat.tsx`. Owns the
/// `ConversationObserver` lifecycle for the duration of the sheet.
struct ConversationChatView: View {
    let wardId: String
    let speakerId: String
    let kind: SlotKind
    let invitation: SpeakerInvitation
    let invitationId: String
    @Environment(TwilioChatClient.self) private var twilio
    let auth: AuthClient

    /// Local mirror of the speaker doc, seeded from the snapshot the
    /// schedule passed in. Held as `@State` so a status change writes
    /// optimistically + the banner / pills re-render without waiting
    /// for the Firestore subscription on the schedule to propagate
    /// (which the pushed view doesn't see — it captured the snapshot
    /// at tap time).
    @State private var speaker: Speaker
    @State private var observer: ConversationObserver?
    @State private var loadError: String?
    @State private var isApplying: Bool = false
    @State private var isSending: Bool = false
    @State private var applyError: String?

    init(
        wardId: String,
        speakerId: String,
        kind: SlotKind,
        speaker: Speaker,
        invitation: SpeakerInvitation,
        invitationId: String,
        auth: AuthClient
    ) {
        self.wardId = wardId
        self.speakerId = speakerId
        self.kind = kind
        self.invitation = invitation
        self.invitationId = invitationId
        self.auth = auth
        self._speaker = State(initialValue: speaker)
    }

    var body: some View {
        VStack(spacing: 0) {
            InvitationStatusBannerView(
                speaker: speaker,
                invitation: invitation,
                membersByUid: membersByUid,
                currentUserUid: auth.uid,
                isApplying: isApplying,
                applyError: applyError,
                onApply: handleApply,
                onChangeStatus: handleStatusChange
            )
            Divider()
            if let observer {
                ConversationThreadView(
                    messages: observer.messages,
                    currentIdentity: observer.identity,
                    authors: observer.authors,
                    firstUnreadIndex: observer.firstUnreadIndex,
                    readHorizonIndex: observer.readHorizonIndex,
                    loading: observer.loading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                TypingIndicatorView(
                    identities: observer.typingIdentities,
                    authors: observer.authors
                )
            } else if let loadError {
                errorState(message: loadError)
            } else {
                ConversationThreadView(
                    messages: [],
                    currentIdentity: nil,
                    authors: [:],
                    firstUnreadIndex: nil,
                    readHorizonIndex: nil,
                    loading: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ConversationComposerView(
                placeholder: composerPlaceholder,
                isSending: isSending,
                onTyping: { observer?.notifyTyping() },
                onSend: handleSend
            )
            .disabled(observer == nil)
            .opacity(observer == nil ? 0.6 : 1.0)
        }
        .task(id: invitation.conversationSid) {
            await ensureObserver()
        }
        .onDisappear {
            observer?.detach()
            observer = nil
        }
    }

    private var membersByUid: [String: String] {
        var map: [String: String] = [:]
        for participant in invitation.bishopricParticipants {
            map["uid:\(participant.uid)"] = participant.displayName
        }
        return map
    }

    private var composerPlaceholder: String {
        switch kind {
        case .speaker:                              return "Message the speaker…"
        case .openingPrayer, .benediction:          return "Message the prayer giver…"
        }
    }

    private var bishopUid: String? {
        guard let uid = auth.uid else { return nil }
        return "uid:\(uid)"
    }

    @MainActor
    private func ensureObserver() async {
        guard observer == nil else { return }
        guard let conversationSid = invitation.conversationSid else {
            loadError = "This invitation has no Twilio conversation. Re-prepare it from the schedule."
            return
        }
        // Connect lazily — TwilioChatClient's connect() is idempotent
        // so even if the user already opened the debug screen, this
        // resolves immediately.
        await twilio.connect(wardId: wardId)
        do {
            let next = try await twilio.observer(forSid: conversationSid, invitation: invitation)
            // Twilio's speaker identity is `speaker:{invitationId}` —
            // the observer can now resolve the speaker side correctly.
            next.setSpeakerAuthor(
                identity: "speaker:\(invitationId)",
                displayName: invitation.speakerName
            )
            observer = next
            // Mark-read on open so the unread divider doesn't keep
            // appearing for messages the bishop just looked at.
            await next.setAllMessagesRead()
        } catch {
            loadError = "Couldn't load the conversation — \(error.localizedDescription)"
        }
    }

    private func handleApply() {
        // Apply (acknowledge) speaker response — this is where the
        // web calls `applyResponseToSpeaker`. The iOS port doesn't
        // expose that callable yet (it's a Cloud Function on the web
        // side), so v1 just flips local status to confirmed/declined
        // based on the response answer. The deeper acknowledgedAt
        // stamp lands when we wire the callable later.
        guard let answer = invitation.response?.answer else { return }
        let next: InvitationStatus = (answer == "yes") ? .confirmed : .declined
        handleStatusChange(next)
    }

    private func handleStatusChange(_ next: InvitationStatus) {
        guard let bishopUid = auth.uid else { return }
        Task {
            isApplying = true
            applyError = nil
            defer { isApplying = false }
            do {
                switch kind {
                case .speaker:
                    try await SpeakerStatusClient.updateSpeakerStatus(
                        wardId: wardId,
                        meetingDate: invitation.speakerRef.meetingDate,
                        speakerId: speakerId,
                        status: next,
                        setBy: bishopUid
                    )
                case .openingPrayer, .benediction:
                    try await SpeakerStatusClient.updatePrayerStatus(
                        wardId: wardId,
                        meetingDate: invitation.speakerRef.meetingDate,
                        kind: kind,
                        status: next,
                        setBy: bishopUid
                    )
                }
                // Optimistic local refresh — the pushed view doesn't
                // see the schedule's CollectionSubscription update,
                // so reconstruct the speaker so banner + pills repaint.
                speaker = Speaker(
                    name: speaker.name,
                    email: speaker.email,
                    phone: speaker.phone,
                    topic: speaker.topic,
                    status: next.rawValue,
                    role: speaker.role,
                    order: speaker.order,
                    statusSource: "manual",
                    statusSetBy: bishopUid,
                    invitationId: speaker.invitationId
                )
                await InvitationStatusMirror.mirrorCurrentSpeakerStatus(
                    wardId: wardId,
                    invitationId: invitationId,
                    status: next
                )
                if let conversation = observer?.conversation {
                    await InvitationStatusMirror.postStatusChangeMessage(
                        conversation: conversation,
                        status: next,
                        meetingDate: invitation.speakerRef.meetingDate
                    )
                }
            } catch {
                applyError = "Couldn't update status — \(error.localizedDescription)"
            }
        }
    }

    private func handleSend(_ body: String) async {
        guard let observer else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await observer.send(body: body)
        } catch {
            applyError = "Couldn't send — \(error.localizedDescription)"
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: Spacing.s2) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bordeaux)
            Text(message)
                .font(.bodyDefault)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
