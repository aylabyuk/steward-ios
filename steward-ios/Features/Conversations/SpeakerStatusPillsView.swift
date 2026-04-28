import SwiftUI
import StewardCore

/// 4-state segmented control: PLANNED / INVITED / CONFIRMED / DECLINED.
/// Mirrors the web's `SpeakerStatusPills.tsx`. Tapping a non-current
/// state pops a confirmation dialog (`StatusConfirmCopy`) — rollbacks
/// out of terminal states get heavier-friction copy.
struct SpeakerStatusPillsView: View {
    let current: InvitationStatus
    let currentStatusSource: String?
    let currentStatusSetBy: String?
    let membersByUid: [String: String]
    let currentUserUid: String?
    /// Called when the user confirms a transition. The pills owns the
    /// confirm dialog — by the time this fires, the bishop has
    /// acknowledged the friction.
    let onChange: (InvitationStatus) -> Void

    @State private var pending: InvitationStatus?

    private static let order: [InvitationStatus] = [.planned, .invited, .confirmed, .declined]

    /// Single-row segmented control height. Tuned to read the same as
    /// the web's pills (`SpeakerStatusPills.tsx` ships ~38px-tall
    /// buttons with mono labels) without towering over the banner.
    private static let pillHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.order, id: \.self) { status in
                pill(for: status)
                if status != Self.order.last {
                    divider
                }
            }
        }
        .frame(height: Self.pillHeight)
        .background(Color.chalk)
        .clipShape(RoundedRectangle(cornerRadius: Radius.default, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                .stroke(Color.borderStrong, lineWidth: 0.5)
        )
        .alert(item: $pending) { next in
            Alert(
                title: Text(copy(for: next).title),
                message: Text(copy(for: next).body),
                primaryButton: copy(for: next).danger
                    ? .destructive(Text(copy(for: next).confirmLabel)) {
                        onChange(next)
                    }
                    : .default(Text(copy(for: next).confirmLabel)) {
                        onChange(next)
                    },
                secondaryButton: .cancel()
            )
        }
    }

    private func pill(for status: InvitationStatus) -> some View {
        Button {
            request(status)
        } label: {
            Text(label(for: status))
                .font(.monoEyebrow)
                .tracking(1.0)
                .foregroundStyle(textColor(for: status))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background(for: status))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(status == current ? [.isSelected] : [])
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 0.5, height: Self.pillHeight)
    }

    private func request(_ next: InvitationStatus) {
        guard next != current else { return }
        // "invited → planned" is frictionless on the web (no real
        // commitment to erase). Mirror that here.
        let isTerminal = current == .confirmed || current == .declined
        if !isTerminal && next == .planned {
            onChange(next)
            return
        }
        pending = next
    }

    private func copy(for next: InvitationStatus) -> StatusConfirmCopy.Result {
        StatusConfirmCopy.compute(
            current: current.rawValue,
            next: next.rawValue,
            currentStatusSource: currentStatusSource,
            currentStatusSetBy: currentStatusSetBy,
            membersByUid: membersByUid,
            currentUserUid: currentUserUid
        )
    }

    private func label(for status: InvitationStatus) -> String {
        switch status {
        case .planned:    return "PLANNED"
        case .invited:    return "INVITED"
        case .confirmed:  return "CONFIRMED"
        case .declined:   return "DECLINED"
        }
    }

    private func textColor(for status: InvitationStatus) -> Color {
        if status == current {
            return tone(for: status).strongText
        }
        return Color.walnut2
    }

    private func background(for status: InvitationStatus) -> Color {
        if status == current {
            return tone(for: status).fill
        }
        return Color.chalk
    }

    private struct ToneColors {
        let fill: Color
        let strongText: Color
    }

    private func tone(for status: InvitationStatus) -> ToneColors {
        switch status {
        case .planned:
            return ToneColors(fill: Color.parchment2, strongText: Color.walnut)
        case .invited:
            return ToneColors(fill: Color.brassSoft, strongText: Color.walnut)
        case .confirmed:
            return ToneColors(fill: Color.successSoft, strongText: Color.success)
        case .declined:
            return ToneColors(fill: Color.dangerSoft, strongText: Color.bordeaux)
        }
    }
}

extension InvitationStatus: @retroactive Identifiable {
    public var id: String { rawValue }
}
