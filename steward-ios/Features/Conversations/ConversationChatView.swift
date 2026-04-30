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
    /// Live speaker doc passed from `ConversationView`'s subscription.
    /// Updates whenever Firestore emits — drives the banner + pills
    /// without any local @State, so cross-device status changes
    /// (web ↔ iOS, iOS ↔ iOS) repaint the moment the write lands.
    let speaker: Speaker
    let invitation: SpeakerInvitation
    let invitationId: String
    @Environment(TwilioChatClient.self) private var twilio
    let auth: AuthClient

    @State private var observer: ConversationObserver?
    @State private var loadError: String?
    @State private var isApplying: Bool = false
    @State private var isSending: Bool = false
    @State private var applyError: String?
    /// Non-nil while the edit-message sheet is presented. Driven by
    /// `.sheet(item:)` on the chat view.
    @State private var editing: ChatMessage?

    var body: some View {
        VStack(spacing: 0) {
            InvitationStatusBannerView(
                speaker: speaker,
                invitation: invitation,
                kind: kind,
                membersByUid: membersByUid,
                currentUserUid: auth.uid,
                isApplying: isApplying,
                applyError: applyError,
                onApply: handleApply,
                onChangeStatus: handleStatusChange
            )
            Divider()
            if let observer {
                let permissions = MessagePermissions.build(
                    currentIdentity: observer.identity,
                    messages: observer.messages
                )
                ConversationThreadView(
                    messages: observer.messages,
                    currentIdentity: observer.identity,
                    authors: observer.authors,
                    firstUnreadIndex: observer.firstUnreadIndex,
                    readHorizonIndex: observer.readHorizonIndex,
                    loading: observer.loading,
                    canDelete: permissions.canDelete,
                    onDelete: handleDelete,
                    canEdit: permissions.canEdit,
                    onEdit: handleEdit,
                    onToggleReaction: handleToggleReaction
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
        .sheet(item: $editing) { message in
            ConversationEditMessageSheet(message: message, onSave: commitEdit)
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
        // Re-entrance guard + synchronous state flip. Without these,
        // a second tap during the brief window between the button's
        // `onApply` firing and SwiftUI re-rendering with
        // `.disabled(isApplying)` can queue a duplicate Task — which
        // double-writes status, double-mirrors, and posts the
        // "Assignment confirmed…" system message twice.
        guard !isApplying else { return }
        isApplying = true
        applyError = nil
        Task {
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
                // No local optimistic update — `ConversationView`'s
                // `DocSubscription<Speaker>` will emit the new state
                // moments after the Firestore write lands (typically
                // <100ms locally), and that supersedes the snapshot
                // for both the banner + pills.
                await InvitationStatusMirror.mirrorCurrentSpeakerStatus(
                    wardId: wardId,
                    invitationId: invitationId,
                    status: next
                )
                if let conversation = observer?.conversation {
                    await InvitationStatusMirror.postStatusChangeMessage(
                        conversation: conversation,
                        status: next,
                        kind: kind,
                        meetingDate: invitation.speakerRef.meetingDate
                    )
                }
            } catch {
                applyError = "Couldn't update status — \(error.localizedDescription)"
            }
        }
    }

    /// Delete a message. Mirrors `BubbleActions.tsx` on the web — the
    /// permission check is already at the contextMenu (gated by
    /// `MessagePermissions.canDelete`), so this just runs the two
    /// side-effects: remove the message from Twilio (which fans out
    /// `messageRemoved` to every other client) and post a tombstone
    /// system notice in its place. Tombstone is iOS-only — see
    /// `docs/web-deviations.md`.
    private func handleDelete(_ message: ChatMessage) {
        guard let observer else { return }
        let conversation = observer.conversation
        let removedBy = bishopDisplayName
        Task {
            do {
                try await observer.remove(messageSid: message.sid)
                await InvitationStatusMirror.postMessageDeletedNotice(
                    conversation: conversation,
                    removedBy: removedBy
                )
            } catch {
                applyError = "Couldn't delete the message — \(error.localizedDescription)"
            }
        }
    }

    /// Open the edit-message sheet. Permission is already gated at
    /// the bubble's contextMenu (via `MessagePermissions.canEdit`),
    /// so we can trust the message reference here.
    private func handleEdit(_ message: ChatMessage) {
        editing = message
    }

    /// Apply the bishop's edit. `EditMessageIntent.normalize` filters
    /// out blank or unchanged proposals so we don't waste a Twilio
    /// write — when it returns nil, the sheet has already dismissed
    /// itself and we just bail.
    private func commitEdit(_ message: ChatMessage, proposed: String) {
        guard let observer else { return }
        guard let body = EditMessageIntent.normalize(
            currentBody: message.body,
            proposedBody: proposed
        ) else { return }
        Task {
            do {
                try await observer.updateBody(messageSid: message.sid, body: body)
            } catch {
                applyError = "Couldn't edit the message — \(error.localizedDescription)"
            }
        }
    }

    /// Toggle a reaction on a message via the observer. The Twilio
    /// `setAttributes` call is best-effort — we surface the error
    /// inline so the bishop knows the reaction didn't land, but
    /// don't roll back optimistically since there's no local mirror
    /// to roll back to (the messageUpdated delegate emits the new
    /// state once the write succeeds).
    private func handleToggleReaction(_ message: ChatMessage, emoji: String) {
        guard let observer else { return }
        Task {
            do {
                try await observer.toggleReaction(messageSid: message.sid, emoji: emoji)
            } catch {
                applyError = "Couldn't react — \(error.localizedDescription)"
            }
        }
    }

    private var bishopDisplayName: String? {
        if let displayName = auth.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           displayName.isEmpty == false {
            return displayName
        }
        if let email = auth.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           email.isEmpty == false {
            return email
        }
        return nil
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
