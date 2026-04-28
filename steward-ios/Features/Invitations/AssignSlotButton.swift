import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// The tappable pill that replaces the inert "Not assigned" placeholder
/// on each empty slot. Lower-emphasis than a primary CTA — quietly
/// invites a tap without shouting louder than a real assignee on the
/// row above it. Action goes through a closure so the parent view
/// (`MeetingCardBody`) decides what happens (push onto the schedule's
/// nav stack with the right `SlotContext`).
struct AssignSlotButton: View {
    let kind: SlotKind
    /// Optional override for the button copy. Defaults to
    /// `kind.assignButtonLabel`. Used by the meeting card's "Add another
    /// speaker" row, which reuses this same affordance with different
    /// copy.
    var label: String? = nil
    let action: () -> Void

    private var effectiveLabel: String {
        label ?? kind.assignButtonLabel
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brassDeep)
                Text(effectiveLabel)
                    .font(.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.walnut)
            }
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s2)
            .background(Color.parchment2, in: .capsule)
            .overlay(Capsule().stroke(Color.border.opacity(0.7), lineWidth: 0.5))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(effectiveLabel)
        .accessibilityHint("Opens a form to fill in the assignee's details.")
    }
}
#endif
