import SwiftUI
import StewardCore

/// Slim status header above the chat thread. iOS deviation from the
/// web's `InvitationStatusBanner.tsx` — no full-width tone fill, no
/// dedicated pills row. The tone now lives in the message colour and
/// the (interactive) `StatusBadge` sitting on the same line; the
/// banner sits flat on the parchment so the chat owns the rest of
/// the screen.
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

    private var provenanceLabel: String? {
        BannerView.statusProvenanceLabel(speaker: speaker, membersByUid: membersByUid)
    }

    var body: some View {
        let result = bannerResult
        let provenance = provenanceLabel
        let lastSeen = lastSeenLabel

        return VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.message)
                        .font(.bodyEmphasis)
                        .foregroundStyle(color(for: result.tone))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let reason = invitation.response?.reason, !reason.isEmpty {
                        Text("\u{201C}\(reason)\u{201D}")
                            .font(.serifAside)
                            .foregroundStyle(Color.walnut2)
                    }
                    if let lastSeen {
                        Text(lastSeen.uppercased())
                            .font(.monoEyebrow)
                            .tracking(1.0)
                            .foregroundStyle(Color.walnut3)
                    }
                }
                SpeakerStatusPillsView(
                    current: InvitationStatus(rawString: speaker.status) ?? .planned,
                    currentStatusSource: speaker.statusSource,
                    currentStatusSetBy: speaker.statusSetBy,
                    membersByUid: membersByUid,
                    currentUserUid: currentUserUid,
                    onChange: onChangeStatus
                )
                .fixedSize()
            }
            if let applyError {
                Text(applyError)
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
            }
            if provenance != nil || result.showApply {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
                    if let provenance {
                        Text(provenance)
                            .font(.monoEyebrow)
                            .tracking(1.0)
                            .foregroundStyle(Color.walnut3)
                    }
                    Spacer(minLength: 0)
                    if result.showApply, let applyLabel = result.applyLabel {
                        Button {
                            onApply()
                        } label: {
                            Text(isApplying ? "Applying…" : applyLabel)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.bordeaux)
                        .controlSize(.small)
                        .disabled(isApplying)
                        .accessibilityHint("Records the speaker's reply on the schedule.")
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s3)
    }

    private func color(for tone: BannerView.Tone) -> Color {
        switch tone {
        case .success:     return Color.success
        case .pending:     return Color.brassDeep
        case .destructive: return Color.bordeaux
        case .neutral:     return Color.walnut2
        }
    }
}
