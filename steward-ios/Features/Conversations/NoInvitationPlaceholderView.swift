import SwiftUI
import StewardCore

/// Body shown when the bishop opens the chat sheet on a speaker /
/// prayer that hasn't been invited yet (no `invitationId` on the
/// speaker doc, no Twilio conversation). Mirrors the web's
/// `NoInvitationPlaceholder.tsx` — explains why chat isn't available
/// and points to the Assign + Invite flow.
struct NoInvitationPlaceholderView: View {
    let speakerName: String
    let speakerStatus: InvitationStatus

    var body: some View {
        VStack(alignment: .center, spacing: Spacing.s3) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.brassDeep)
            Text(title)
                .font(.displaySection)
                .foregroundStyle(Color.walnut)
                .multilineTextAlignment(.center)
            Text(body(for: speakerStatus))
                .font(.bodyDefault)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Spacing.s6)
    }

    private var title: String {
        switch speakerStatus {
        case .planned:    return "No invitation sent yet"
        case .invited:    return "No in-app invitation on file"
        case .confirmed:  return "Confirmed outside Steward"
        case .declined:   return "Declined outside Steward"
        }
    }

    private func body(for status: InvitationStatus) -> String {
        switch status {
        case .planned:
            return "Open this row from the schedule and tap Mark as Invited to mint an invitation. Once that lands, the chat appears here."
        case .invited:
            return "\(speakerName)'s status is set to \"invited\" but no in-app invitation was sent. The chat only works for invitations sent through Steward."
        case .confirmed:
            return "\(speakerName)'s status was set to confirmed without an in-app invitation. The conversation only opens for invitations sent through Steward."
        case .declined:
            return "\(speakerName)'s status was set to declined without an in-app invitation. The conversation only opens for invitations sent through Steward."
        }
    }
}
