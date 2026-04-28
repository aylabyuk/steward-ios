import SwiftUI
import StewardCore

/// Top-of-sheet banner with status copy + status pills. Mirrors the
/// web's `InvitationStatusBanner.tsx`. Three distinct rows:
///   1. Headline message + tone fill (driven by `BannerView.derive`).
///   2. Optional Apply CTA (when the speaker has replied but the
///      bishopric hasn't acknowledged).
///   3. Status pills (`SpeakerStatusPillsView`) for manual override.
struct InvitationStatusBannerView: View {
    let speaker: Speaker
    let invitation: SpeakerInvitation
    let membersByUid: [String: String]
    let currentUserUid: String?
    let isApplying: Bool
    let applyError: String?
    let onApply: () -> Void
    let onChangeStatus: (InvitationStatus) -> Void

    private var bannerResult: BannerView.Result {
        BannerView.derive(speaker: speaker, invitation: invitation)
    }

    private var lastSeenLabel: String? {
        BannerView.formatLastSeen(invitation.speakerLastSeenAt)
    }

    /// Provenance line shown under the pills. Status-aware — flips
    /// from "INVITED BY..." to "SET MANUALLY BY..." to "FROM REPLY ·
    /// APPLIED BY..." as the bishopric works through the lifecycle.
    private var provenanceLabel: String? {
        BannerView.statusProvenanceLabel(speaker: speaker, membersByUid: membersByUid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2 + 2) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bannerResult.message)
                        .font(.bodyEmphasis)
                        .foregroundStyle(messageColor)
                    if let reason = invitation.response?.reason, !reason.isEmpty {
                        Text("\u{201C}\(reason)\u{201D}")
                            .font(.serifAside)
                            .foregroundStyle(Color.walnut2)
                    }
                    if let lastSeenLabel {
                        Text(lastSeenLabel.uppercased())
                            .font(.monoEyebrow)
                            .tracking(1.0)
                            .foregroundStyle(Color.walnut3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if bannerResult.showApply, let applyLabel = bannerResult.applyLabel {
                    Button {
                        onApply()
                    } label: {
                        Text(isApplying ? "Applying…" : applyLabel)
                            .font(.bodySmall)
                            .foregroundStyle(Color.parchment)
                            .padding(.horizontal, Spacing.s3)
                            .padding(.vertical, Spacing.s2)
                            .background(
                                Color.bordeaux,
                                in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)
                    .opacity(isApplying ? 0.6 : 1)
                }
            }
            if let applyError {
                Text(applyError)
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
            }
            SpeakerStatusPillsView(
                current: InvitationStatus(rawString: speaker.status) ?? .planned,
                currentStatusSource: speaker.statusSource,
                currentStatusSetBy: speaker.statusSetBy,
                membersByUid: membersByUid,
                currentUserUid: currentUserUid,
                onChange: onChangeStatus
            )
            if let provenanceLabel {
                Text(provenanceLabel)
                    .font(.monoEyebrow)
                    .tracking(1.0)
                    .foregroundStyle(Color.walnut3)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .background(toneFill)
    }

    private var messageColor: Color {
        switch bannerResult.tone {
        case .success:     return Color.success
        case .pending:     return Color.brassDeep
        case .destructive: return Color.bordeaux
        case .neutral:     return Color.walnut2
        }
    }

    private var toneFill: Color {
        switch bannerResult.tone {
        case .success:     return Color.successSoft
        case .pending:     return Color.brassSoft
        case .destructive: return Color.dangerSoft
        case .neutral:     return Color.parchment2
        }
    }
}
