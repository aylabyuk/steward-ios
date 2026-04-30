import SwiftUI
import StewardCore

/// Single message bubble. Mirrors the web's `ConversationBubble.tsx`:
///   * "Mine" → bordeaux fill, parchment text, right-aligned.
///   * Theirs → parchment fill, walnut text, left-aligned.
///   * Quick-action `Yes` / `No` responses get a coloured outline.
///   * "Edited" tag when `wasEdited` is true.
struct ConversationBubbleView: View {
    let message: ChatMessage
    let mine: Bool
    /// Position within a same-author group. Drives the corner-radius
    /// asymmetry that makes a stack of consecutive messages read as a
    /// single thought.
    let position: Position
    /// True when the current viewer is allowed to delete this message
    /// (within the 24h window + last-5 cap, per `MessagePermissions`).
    /// Drives whether a long-press contextMenu attaches at all — we
    /// don't want a long-press to steal the gesture and then show
    /// nothing.
    var canDelete: Bool = false
    var onDelete: () -> Void = {}
    /// True when the current viewer authored this message and is
    /// still inside the edit window (same gates as delete, plus a
    /// strict identity match). Edit + Delete coexist when both true.
    var canEdit: Bool = false
    var onEdit: () -> Void = {}
    /// Identity of the current viewer — used to highlight chips the
    /// viewer has reacted with and to feed `toggleReaction` writes.
    /// Nil means the viewer hasn't been resolved yet (loading
    /// state); reactions display read-only.
    var currentIdentity: String? = nil
    /// Fires with the chosen emoji when the viewer toggles a
    /// reaction (from the long-press popover OR by tapping an
    /// existing chip). Parent owns the Twilio write.
    var onToggleReaction: (String) -> Void = { _ in }

    @State private var showingActions: Bool = false
    @State private var pressing: Bool = false

    enum Position { case single, first, middle, last }

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            if let responseLabel {
                Text(responseLabel.uppercased())
                    .font(.monoEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(responseLabelColor)
            }
            bubble
            if message.reactions.nonEmpty {
                reactionChips
            }
            if message.wasEdited {
                Text("Edited")
                    .font(.monoMicro)
                    .tracking(1.0)
                    .foregroundStyle(Color.walnut3)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    /// Stack of small chips that overlap the bottom of the bubble —
    /// Messenger-style. One per emoji that has at least one reaction.
    /// Tap a chip to toggle the viewer's reaction with that emoji.
    /// The chip the viewer has already reacted with renders with a
    /// tinted ring so they can see their participation at a glance.
    private var reactionChips: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions.orderedEntries, id: \.emoji) { entry in
                let mineReaction = currentIdentity.map { entry.identities.contains($0) } ?? false
                Button {
                    onToggleReaction(entry.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(entry.emoji).font(.system(size: 13))
                        if entry.identities.count > 1 {
                            Text("\(entry.identities.count)")
                                .font(.monoMicro)
                                .tracking(0.4)
                                .foregroundStyle(mineReaction ? Color.bordeaux : Color.walnut2)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        // Frosted material reads cleanly on top of
                        // either bubble fill (bordeaux for mine /
                        // parchment-2 for theirs); a flat color was
                        // disappearing into one or the other.
                        .regularMaterial,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().stroke(
                            mineReaction ? Color.bordeaux.opacity(0.5) : Color.border,
                            lineWidth: 0.5
                        )
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 1.5, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reactionAccessibilityLabel(emoji: entry.emoji, count: entry.identities.count, mine: mineReaction))
            }
        }
        // Negative top padding lifts the chips up so they overlap
        // the bottom-trailing corner of the bubble — matches the
        // Messenger / iMessage convention of "reactions hang off the
        // edge". The shadow + frosted fill let them visually float.
        .padding(.top, -10)
        .padding(mine ? .trailing : .leading, Spacing.s3)
        .zIndex(1)
    }

    private func reactionAccessibilityLabel(emoji: String, count: Int, mine: Bool) -> String {
        let countPart = count == 1 ? "1 reaction" : "\(count) reactions"
        let suffix = mine ? "; tap to remove yours" : "; tap to react"
        return "\(emoji) — \(countPart)\(suffix)"
    }

    @ViewBuilder
    private var bubble: some View {
        let base = Text(message.body)
            .font(.bodyDefault)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s2 + 2)
            .background(bubbleBackground)
            .overlay(bubbleOverlay)
            .clipShape(bubbleShape)
            .frame(maxWidth: 280, alignment: mine ? .trailing : .leading)
            .scaleEffect(pressing ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: pressing)
        if canReact || canEdit || canDelete {
            base
                .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 16) {
                    showingActions = true
                } onPressingChanged: { isPressing in
                    pressing = isPressing
                }
                .popover(isPresented: $showingActions) {
                    BubbleActionsPopoverContent(
                        reactions: message.reactions,
                        currentIdentity: currentIdentity,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        onToggleReaction: onToggleReaction,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        dismiss: { showingActions = false }
                    )
                }
        } else {
            base
        }
    }

    /// Reactions are available to anyone with a resolved identity —
    /// no edit-window gate, no same-side rule. Disabled (`false`)
    /// only when the viewer's identity hasn't loaded.
    private var canReact: Bool { currentIdentity != nil }

    private var bubbleShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius:     mine ? 16 : (position == .first || position == .single ? 16 : 4),
            bottomLeadingRadius:  mine ? 16 : (position == .last  || position == .single ? 16 : 4),
            bottomTrailingRadius: mine ? (position == .last  || position == .single ? 16 : 4) : 16,
            topTrailingRadius:    mine ? (position == .first || position == .single ? 16 : 4) : 16,
            style: .continuous
        )
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if mine {
            Color.bordeaux
        } else {
            Color.parchment
        }
    }

    @ViewBuilder
    private var bubbleOverlay: some View {
        if mine == false, responseOutlineColor != nil {
            bubbleShape.stroke(responseOutlineColor ?? Color.clear, lineWidth: 1.5)
        } else if mine == false {
            bubbleShape.stroke(Color.border, lineWidth: 0.5)
        }
    }

    private var textColor: Color {
        mine ? Color.parchment : Color.walnut
    }

    private var responseLabel: String? {
        guard case let .response(answer, _) = message.attributes else { return nil }
        return "Response · \(answer)"
    }

    private var responseLabelColor: Color {
        guard case let .response(answer, _) = message.attributes else { return Color.walnut2 }
        return answer == "yes" ? Color.success : Color.bordeaux
    }

    private var responseOutlineColor: Color? {
        guard case let .response(answer, _) = message.attributes else { return nil }
        return answer == "yes" ? Color.success : Color.bordeaux
    }
}
