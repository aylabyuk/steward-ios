import SwiftUI
import StewardCore

/// Scrollable thread list. Mirrors the web's `ConversationThread.tsx`:
///   * Vertical scroll, bottom-anchored.
///   * Day separators ("Today" / "Yesterday" / weekday / date).
///   * Unread divider (a "New messages" rule, inserted once).
///   * System notices (centered `SystemNoticeView`).
///   * Author groups (`ConversationGroupView`).
///   * Auto-scrolls to bottom when new messages arrive.
///   * Empty state when there's no message yet ("Say hello — messages
///     appear live…").
///   * Loading state.
struct ConversationThreadView: View {
    let messages: [ChatMessage]
    let currentIdentity: String?
    let authors: [String: AuthorInfo]
    let firstUnreadIndex: Int?
    let readHorizonIndex: Int?
    let loading: Bool
    /// Predicates derived from `MessagePermissions.build(...)` and
    /// the per-message delete handler. Default "never deletable" keeps
    /// loading / empty states + previews safe.
    var canDelete: (ChatMessage) -> Bool = { _ in false }
    var onDelete: (ChatMessage) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if loading {
                    loadingState
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if items.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            row(for: item)
                                .id(item.id)
                        }
                        Color.clear.frame(height: 1).id(Self.bottomAnchor)
                    }
                    .padding(.bottom, Spacing.s4)
                }
            }
            .onChange(of: messages.count) { _, _ in
                guard !messages.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                }
            }
            .onAppear {
                guard !messages.isEmpty else { return }
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    private static let bottomAnchor = "thread-bottom-anchor"

    private var items: [ThreadItem] {
        ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: currentIdentity,
            authors: authors,
            firstUnreadIndex: firstUnreadIndex,
            now: Date()
        )
    }

    @ViewBuilder
    private func row(for item: ThreadItem) -> some View {
        switch item {
        case let .day(_, label):
            dayDivider(label: label)
        case .unread:
            unreadDivider
        case let .system(_, body, status):
            SystemNoticeView(message: body, status: status)
        case let .group(group):
            ConversationGroupView(
                group: group,
                readHorizonIndex: readHorizonIndex,
                canDelete: canDelete,
                onDelete: onDelete
            )
        }
    }

    private func dayDivider(label: String) -> some View {
        HStack(spacing: Spacing.s2) {
            rule
            Text(label.uppercased())
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.brassDeep)
            rule
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    private var unreadDivider: some View {
        HStack(spacing: Spacing.s2) {
            unreadRule
            Text("NEW MESSAGES")
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.bordeaux)
            unreadRule
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s2)
    }

    private var rule: some View {
        Rectangle().fill(Color.border.opacity(0.6)).frame(height: 0.5).frame(maxWidth: .infinity)
    }

    private var unreadRule: some View {
        Rectangle().fill(Color.bordeaux.opacity(0.4)).frame(height: 0.5).frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s2) {
            Text("Say hello — messages appear live for both sides.")
                .font(.serifAside)
                .foregroundStyle(Color.walnut3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.s2) {
            ProgressView()
                .tint(Color.brassDeep)
            Text("Loading conversation…")
                .font(.serifAside)
                .foregroundStyle(Color.walnut3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
