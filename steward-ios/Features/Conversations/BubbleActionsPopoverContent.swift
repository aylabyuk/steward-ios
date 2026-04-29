import SwiftUI
import StewardCore

/// iMessage-style stacked content for the bubble's long-press popover:
/// a horizontal capsule pill of reaction emojis on top, then a small
/// rounded-rect action card with Edit / Delete rows below. Anchored to
/// the bubble via the parent's `.popover(isPresented:)` so the user
/// keeps the visual link between the message they pressed and the
/// surfaced actions.
///
/// Pure presentation. The parent owns the `isPresented` state and the
/// per-action handlers; this view fires the handler and dismisses
/// itself via the bound `dismiss` closure (the parent flips the bool
/// back to `false`).
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
    private var showActionsCard: Bool { canEdit || canDelete }

    var body: some View {
        VStack(spacing: Spacing.s2 + 2) {
            if canReact {
                palettePill
            }
            if showActionsCard {
                actionsCard
            }
        }
        .padding(Spacing.s2 + 2)
        // `.presentationCompactAdaptation(.popover)` on the parent
        // pulls iPhone presentation out of the default sheet. Without
        // this, the view body can fight the presentation chrome.
        .presentationCompactAdaptation(.popover)
    }

    private var palettePill: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(Reactions.palette, id: \.self) { emoji in
                paletteButton(emoji: emoji)
            }
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.border, lineWidth: 0.5))
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
                .font(.system(size: 26))
                .frame(width: 38, height: 38)
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

    private var actionsCard: some View {
        VStack(spacing: 0) {
            if canEdit {
                actionRow(
                    label: "Edit",
                    systemImage: "pencil",
                    role: nil
                ) {
                    onEdit()
                    dismiss()
                }
            }
            if canEdit && canDelete {
                Divider()
            }
            if canDelete {
                actionRow(
                    label: "Delete",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    onDelete()
                    dismiss()
                }
            }
        }
        .frame(minWidth: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                .stroke(Color.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func actionRow(
        label: String,
        systemImage: String,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: Spacing.s3) {
                Text(label)
                    .font(.bodyDefault)
                    .foregroundStyle(role == .destructive ? Color.bordeaux : Color.walnut)
                Spacer(minLength: 0)
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(role == .destructive ? Color.bordeaux : Color.walnut2)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
