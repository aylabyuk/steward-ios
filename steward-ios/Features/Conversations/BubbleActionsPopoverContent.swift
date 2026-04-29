import SwiftUI
import StewardCore

/// Single-row content for the bubble's long-press popover: a capsule
/// containing the reaction palette on the leading edge, a thin
/// vertical divider, then icon-only Edit / Delete actions on the
/// trailing edge. One unified container so the rounding stays
/// consistent across the two groups (vs. earlier two-card stack).
///
/// Pure presentation. The parent owns the `isPresented` state and the
/// per-action handlers; this view fires the handler and dismisses
/// itself via the bound `dismiss` closure.
struct BubbleActionsPopoverContent: View {
    let reactions: Reactions
    let currentIdentity: String?
    let canEdit: Bool
    let canDelete: Bool
    let onToggleReaction: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let dismiss: () -> Void

    private var canReact: Bool { currentIdentity != nil }
    private var showActions: Bool { canEdit || canDelete }

    var body: some View {
        HStack(spacing: Spacing.s2) {
            if canReact {
                ForEach(Reactions.palette, id: \.self) { emoji in
                    paletteButton(emoji: emoji)
                }
            }
            if canReact && showActions {
                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 2)
            }
            if canEdit {
                iconButton(systemImage: "pencil", role: nil, label: "Edit") {
                    onEdit()
                    dismiss()
                }
            }
            if canDelete {
                iconButton(systemImage: "trash", role: .destructive, label: "Delete") {
                    onDelete()
                    dismiss()
                }
            }
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.border, lineWidth: 0.5))
        // `.presentationCompactAdaptation(.popover)` on the parent
        // pulls iPhone presentation out of the default sheet. Without
        // this, the view body can fight the presentation chrome.
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private func paletteButton(emoji: String) -> some View {
        let mineReaction = currentIdentity.map {
            reactions.includes(emoji: emoji, identity: $0)
        } ?? false
        Button {
            onToggleReaction(emoji)
            dismiss()
        } label: {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(
                    mineReaction ? Color.dangerSoft : Color.clear,
                    in: Circle()
                )
                .overlay(
                    Circle().stroke(
                        mineReaction ? Color.bordeaux.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            mineReaction
                ? "Remove \(emoji) reaction"
                : "React with \(emoji)"
        )
    }

    @ViewBuilder
    private func iconButton(
        systemImage: String,
        role: ButtonRole?,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(role == .destructive ? Color.bordeaux : Color.walnut)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
