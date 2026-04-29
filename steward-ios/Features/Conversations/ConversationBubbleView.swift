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
            if message.wasEdited {
                Text("Edited")
                    .font(.monoMicro)
                    .tracking(1.0)
                    .foregroundStyle(Color.walnut3)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
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
        if canDelete {
            base
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityHint("Delete this message")
                }
        } else {
            base
        }
    }

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
