import SwiftUI
import StewardCore

/// Speaker-status switcher exposed as a `StatusBadge` that opens a
/// native `Menu`. iOS deviation from the web's `SpeakerStatusPills.tsx`
/// 4-segment radio strip — see `docs/web-deviations.md`. Tapping a
/// non-current state still routes through `StatusConfirmCopy` for the
/// confirm-dialog friction; the menu just removes the tab-bar
/// visual ambiguity and the redundant always-on real estate.
struct SpeakerStatusPillsView: View {
    let current: InvitationStatus
    let currentStatusSource: String?
    let currentStatusSetBy: String?
    let membersByUid: [String: String]
    let currentUserUid: String?
    /// Called when the user confirms a transition. The menu owns the
    /// confirm dialog — by the time this fires, the bishop has
    /// acknowledged the friction.
    let onChange: (InvitationStatus) -> Void

    @State private var pending: InvitationStatus?

    var body: some View {
        Menu {
            menuButton(for: .confirmed, title: "Mark as Confirmed", systemImage: "checkmark.circle")
            menuButton(for: .invited,   title: "Mark as Invited",   systemImage: "envelope")
            menuButton(for: .planned,   title: "Reset to Planned",  systemImage: "arrow.uturn.backward")
            menuButton(for: .declined,  title: "Mark as Declined",  systemImage: "xmark.circle", role: .destructive)
        } label: {
            StatusBadge(rawStatus: current.rawValue)
        }
        .accessibilityHint("Change speaker status")
        .alert(
            pending.map { copy(for: $0).title } ?? "",
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            presenting: pending
        ) { next in
            Button(
                copy(for: next).confirmLabel,
                role: copy(for: next).danger ? .destructive : nil
            ) {
                onChange(next)
            }
            Button("Cancel", role: .cancel) {}
        } message: { next in
            Text(copy(for: next).body)
        }
    }

    @ViewBuilder
    private func menuButton(
        for status: InvitationStatus,
        title: String,
        systemImage: String,
        role: ButtonRole? = nil
    ) -> some View {
        Button(role: role) {
            request(status)
        } label: {
            // SF Symbol overrides to a checkmark for the current
            // status — the menu reads as "this is where you are; tap
            // to move elsewhere."
            Label(title, systemImage: status == current ? "checkmark" : systemImage)
        }
    }

    private func request(_ next: InvitationStatus) {
        switch SpeakerStatusTransition.classify(current: current, next: next) {
        case .noOp:
            return
        case .frictionless:
            onChange(next)
        case .requiresConfirmation:
            pending = next
        }
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
}

