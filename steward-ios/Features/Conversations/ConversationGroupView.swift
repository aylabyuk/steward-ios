import SwiftUI
import StewardCore

/// A vertical stack of consecutive same-author messages. Mirrors the
/// web's `ConversationGroup.tsx`:
///   * Above the bubble stack, an eyebrow label with the author's
///     name (only for non-mine groups — mine bubbles speak for
///     themselves on the right).
///   * Inside the stack, bubbles share a single avatar on the left
///     for theirs, none for mine.
///   * Below the last bubble in the stack, a small timestamp + an
///     optional "Read" label when the other side has read up to here.
struct ConversationGroupView: View {
    let group: MessageGroup
    /// If non-nil, the highest message-index any other participant
    /// has read up to. Drives the "Read" receipt under the last mine
    /// bubble (only when the receipt actually applies).
    let readHorizonIndex: Int?
    /// Predicate the bubble's contextMenu consults to decide whether
    /// to offer Delete. Defaults to "never" so non-chat callsites
    /// (previews, snapshot tests) don't accidentally enable the
    /// affordance.
    var canDelete: (ChatMessage) -> Bool = { _ in false }
    var onDelete: (ChatMessage) -> Void = { _ in }
    /// Same shape for the Edit affordance — gated on
    /// `MessagePermissions.canEdit` upstream.
    var canEdit: (ChatMessage) -> Bool = { _ in false }
    var onEdit: (ChatMessage) -> Void = { _ in }

    var body: some View {
        VStack(alignment: group.mine ? .trailing : .leading, spacing: 2) {
            if !group.mine {
                authorEyebrow
                    .padding(.leading, 36 + Spacing.s2) // align past the avatar column
            }
            HStack(alignment: .top, spacing: Spacing.s2) {
                if !group.mine {
                    avatar
                } else {
                    Spacer(minLength: 0)
                }
                bubbles
                if group.mine {
                    Color.clear.frame(width: 0)
                }
            }
            footer
                .padding(.leading, group.mine ? 0 : 36 + Spacing.s2)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s2)
    }

    private var authorEyebrow: some View {
        Text(group.info.displayName)
            .font(.monoEyebrow)
            .tracking(1.0)
            .foregroundStyle(Color.walnut3)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.brassSoft)
            Text(initial)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.walnut)
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }

    private var bubbles: some View {
        VStack(alignment: group.mine ? .trailing : .leading, spacing: 2) {
            ForEach(Array(group.messages.enumerated()), id: \.element.sid) { offset, message in
                ConversationBubbleView(
                    message: message,
                    mine: group.mine,
                    position: position(for: offset),
                    canDelete: canDelete(message),
                    onDelete: { onDelete(message) },
                    canEdit: canEdit(message),
                    onEdit: { onEdit(message) }
                )
            }
        }
    }

    private var footer: some View {
        VStack(alignment: group.mine ? .trailing : .leading, spacing: 0) {
            if let last = group.messages.last, let date = last.dateCreated {
                Text(date.formatted(.dateTime.hour().minute()))
                    .font(.monoMicro)
                    .tracking(0.6)
                    .foregroundStyle(Color.walnut3)
            }
            if showsReadReceipt {
                Text("Read")
                    .font(.monoMicro)
                    .tracking(1.0)
                    .foregroundStyle(Color.brass)
            }
        }
        .frame(maxWidth: .infinity, alignment: group.mine ? .trailing : .leading)
    }

    private var showsReadReceipt: Bool {
        guard group.mine else { return false }
        guard let horizon = readHorizonIndex,
              let lastIndex = group.messages.last?.index else { return false }
        return horizon >= lastIndex
    }

    private var initial: String {
        let trimmed = group.info.displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.first.map { String($0).uppercased() } ?? "·"
    }

    private func position(for offset: Int) -> ConversationBubbleView.Position {
        if group.messages.count == 1 { return .single }
        if offset == 0 { return .first }
        if offset == group.messages.count - 1 { return .last }
        return .middle
    }
}
