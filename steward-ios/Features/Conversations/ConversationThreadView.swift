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
    /// Same shape for the Edit affordance.
    var canEdit: (ChatMessage) -> Bool = { _ in false }
    var onEdit: (ChatMessage) -> Void = { _ in }
    /// Reaction toggle handler, fired with the message + chosen
    /// emoji. Nil identity disables the affordance.
    var onToggleReaction: (ChatMessage, String) -> Void = { _, _ in }

    /// True when the viewer is within `nearBottomThreshold` points of
    /// the bottom edge. Drives two behaviours:
    ///  - Auto-scroll on new messages only fires when this is true,
    ///    so a viewer reading older history isn't yanked back when a
    ///    new bubble arrives.
    ///  - The "jump to latest" pill shows when this is false.
    @State private var isNearBottom: Bool = true

    /// How close to the bottom (in points) counts as "near". Tuned
    /// so that the auto-scroll-on-new-message keeps up with normal
    /// reading without snapping the viewer mid-scroll.
    private static let nearBottomThreshold: CGFloat = 200

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
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let distanceFromBottom = geometry.contentSize.height
                    - geometry.contentOffset.y
                    - geometry.containerSize.height
                return distanceFromBottom < Self.nearBottomThreshold
            } action: { _, newValue in
                isNearBottom = newValue
            }
            .onChange(of: messages.count) { _, _ in
                guard !messages.isEmpty else { return }
                // Only follow new messages when the viewer is already
                // reading the bottom of the thread. Otherwise leave
                // them where they are; the scroll-to-latest pill is
                // their explicit catch-up affordance.
                guard isNearBottom else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
                }
            }
            .onAppear {
                guard !messages.isEmpty else { return }
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
            .overlay(alignment: .bottomTrailing) {
                if isNearBottom == false && messages.isEmpty == false {
                    scrollToLatestPill(proxy: proxy)
                        .padding(.trailing, Spacing.s3)
                        .padding(.bottom, Spacing.s2)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: isNearBottom)
        }
    }

    /// Floating chevron-down button shown when the viewer has
    /// scrolled away from the latest messages. Tap to animate back
    /// to the bottom anchor.
    private func scrollToLatestPill(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.walnut)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Color.border, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel("Scroll to latest message")
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
                onDelete: onDelete,
                canEdit: canEdit,
                onEdit: onEdit,
                currentIdentity: currentIdentity,
                onToggleReaction: onToggleReaction
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
