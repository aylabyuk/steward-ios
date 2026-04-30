import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// Pushed destination on the Schedule navigation stack — opens when
/// a bishop taps a speaker / prayer name on the schedule. Branches on
/// whether the live speaker doc resolves an `invitationId` — chat
/// pane if it does, placeholder if it doesn't.
///
/// Owns two live subscriptions:
///   * **Speaker / prayer doc** — for cross-device sync. When another
///     bishopric member changes the status from web (or another iOS
///     device), the change lands here and the banner + pills repaint
///     without the bishop needing to back out.
///   * **Invitation doc** — for `currentSpeakerStatus` mirror reads,
///     `speakerLastSeenAt` heartbeat, and the bishopric participant
///     snapshot the chat thread uses to resolve identities.
///
/// First-paint uses the snapshot the schedule passed in; the
/// subscriptions supersede it once they emit.
struct ConversationView: View {
    let wardId: String
    let meetingDate: String
    let speakerId: String
    let kind: SlotKind
    let speaker: Speaker
    let auth: AuthClient

    @State private var invitationSubscription: DocSubscription<SpeakerInvitation>?
    @State private var speakerSubscription: DocSubscription<Speaker>?

    /// The freshest speaker we know about — live subscription if it
    /// has emitted, otherwise the snapshot we were pushed with.
    private var liveSpeaker: Speaker {
        speakerSubscription?.data ?? speaker
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle(liveSpeaker.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: liveSpeaker.invitationId) {
            ensureInvitationSubscription()
        }
        .task {
            ensureSpeakerSubscription()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let subscription = invitationSubscription {
            if subscription.loading {
                loading
            } else if let invitation = subscription.data,
                      let invitationId = liveSpeaker.invitationId {
                ConversationChatView(
                    wardId: wardId,
                    speakerId: speakerId,
                    kind: kind,
                    speaker: liveSpeaker,
                    invitation: invitation,
                    invitationId: invitationId,
                    auth: auth
                )
            } else {
                NoInvitationPlaceholderView(
                    speakerName: liveSpeaker.name,
                    speakerStatus: InvitationStatus(rawString: liveSpeaker.status) ?? .planned
                )
            }
        } else {
            NoInvitationPlaceholderView(
                speakerName: liveSpeaker.name,
                speakerStatus: InvitationStatus(rawString: liveSpeaker.status) ?? .planned
            )
        }
    }

    private var loading: some View {
        VStack(spacing: Spacing.s2) {
            ProgressView().tint(Color.brassDeep)
            Text("Loading conversation…")
                .font(.serifAside)
                .foregroundStyle(Color.walnut3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureInvitationSubscription() {
        guard let invitationId = liveSpeaker.invitationId, invitationSubscription == nil else { return }
        let source = FirestoreDocSource(
            path: "wards/\(wardId)/speakerInvitations/\(invitationId)"
        )
        invitationSubscription = DocSubscription<SpeakerInvitation>(
            source: source,
            decoder: { try JSONDecoder().decode(SpeakerInvitation.self, from: $0) }
        )
    }

    /// For speakers, subscribe to `meetings/{date}/speakers/{id}` and
    /// decode the doc straight into `Speaker`. For prayers, subscribe
    /// to `meetings/{date}/prayers/{role}` — that doc carries only
    /// status fields (no name / email / phone / invitationId, since
    /// those live on the inline meeting assignment), so decoding it
    /// into a vanilla `Speaker` would fail on the non-optional `name`.
    /// Merge the live status fields onto the snapshot via
    /// `Speaker.merging(prayerParticipantJSON:)` so the chat banner
    /// reflects up-to-date status without losing identity.
    private func ensureSpeakerSubscription() {
        guard speakerSubscription == nil else { return }
        switch kind {
        case .speaker:
            let path = "wards/\(wardId)/meetings/\(meetingDate)/speakers/\(speakerId)"
            speakerSubscription = DocSubscription<Speaker>(
                source: FirestoreDocSource(path: path),
                decoder: { try JSONDecoder().decode(Speaker.self, from: $0) }
            )
        case .openingPrayer, .benediction:
            let path = "wards/\(wardId)/meetings/\(meetingDate)/prayers/\(speakerId)"
            let snapshot = speaker
            speakerSubscription = DocSubscription<Speaker>(
                source: FirestoreDocSource(path: path),
                decoder: { try snapshot.merging(prayerParticipantJSON: $0) }
            )
        }
    }
}

#endif
