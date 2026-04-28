import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// Pushed destination on the Schedule navigation stack — opens when
/// a bishop taps a speaker / prayer name on the schedule. Branches on
/// whether `speaker.invitationId` resolves to a real
/// `speakerInvitations/{id}` doc — chat pane if it does, placeholder
/// if it doesn't.
///
/// Subscribes to the invitation doc directly so the banner + thread
/// stay live as the speaker's response or the bishop's status write
/// lands.
///
/// Originally a bottom sheet; promoted to a navigation push because
/// chat is a destination (Apple's own Messages, plus WhatsApp,
/// Slack, etc. all push), keyboard handling on a push is cleaner
/// than on a sheet, and the schedule-context-behind-it benefit
/// didn't pay off on phone-sized screens.
struct ConversationView: View {
    let wardId: String
    let speakerId: String
    let kind: SlotKind
    let speaker: Speaker
    let auth: AuthClient

    @State private var invitationSubscription: DocSubscription<SpeakerInvitation>?

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle(speaker.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: speaker.invitationId) {
            ensureSubscription()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let subscription = invitationSubscription {
            if subscription.loading {
                loading
            } else if let invitation = subscription.data,
                      let invitationId = speaker.invitationId {
                ConversationChatView(
                    wardId: wardId,
                    speakerId: speakerId,
                    kind: kind,
                    speaker: speaker,
                    invitation: invitation,
                    invitationId: invitationId,
                    auth: auth
                )
            } else {
                NoInvitationPlaceholderView(
                    speakerName: speaker.name,
                    speakerStatus: InvitationStatus(rawString: speaker.status) ?? .planned
                )
            }
        } else {
            // No invitationId on the speaker — render placeholder
            NoInvitationPlaceholderView(
                speakerName: speaker.name,
                speakerStatus: InvitationStatus(rawString: speaker.status) ?? .planned
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

    private func ensureSubscription() {
        guard let invitationId = speaker.invitationId, invitationSubscription == nil else { return }
        let source = FirestoreDocSource(
            path: "wards/\(wardId)/speakerInvitations/\(invitationId)"
        )
        invitationSubscription = DocSubscription<SpeakerInvitation>(
            source: source,
            decoder: { try JSONDecoder().decode(SpeakerInvitation.self, from: $0) }
        )
    }
}

#endif
