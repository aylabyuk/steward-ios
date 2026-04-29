import SwiftUI
import StewardCore

/// Reveals a destructive trailing action on left-swipe. Custom because
/// SwiftUI's built-in `.swipeActions` only works inside a `List`, and
/// the schedule uses a `LazyVStack(pinnedViews: [.sectionHeaders])` for
/// the sticky-date-strip layout that `List` doesn't support cleanly.
///
/// On left-swipe past half the action width, the row latches open and
/// the red Delete button is tappable. Tapping the row content while
/// open snaps it closed instead of triggering the wrapped tap target.
struct SwipeToDeleteRow<Content: View>: View {
    /// Fires when the user taps the revealed Delete button.
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    /// Width of the revealed delete chip.
    private static var actionWidth: CGFloat { 88 }

    @State private var dragOffset: CGFloat = 0
    @State private var latched: Bool = false

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction
                .frame(width: Self.actionWidth)

            content()
                .background(Color.parchment)
                .contentShape(Rectangle())
                .offset(x: clampedOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            // Only horizontal-dominant gestures consume.
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let base = latched ? -Self.actionWidth : 0
                            dragOffset = base + value.translation.width
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.18)) {
                                let base = latched ? -Self.actionWidth : 0
                                let final = base + value.translation.width
                                if final < -Self.actionWidth / 2 {
                                    latched = true
                                    dragOffset = -Self.actionWidth
                                } else {
                                    latched = false
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    if latched {
                        // Tap-to-close while latched — only after this
                        // closes do we re-enable the underlying row's
                        // tap target.
                        withAnimation(.easeOut(duration: 0.18)) {
                            latched = false
                            dragOffset = 0
                        }
                    }
                }
        }
        .clipped()
    }

    /// Clamp the drag so it can't pull right past 0 or left past the
    /// action width — keeps the gesture honest on overscroll.
    private var clampedOffset: CGFloat {
        max(min(dragOffset, 0), -Self.actionWidth)
    }

    private var deleteAction: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                latched = false
                dragOffset = 0
            }
            onDelete()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "trash.fill")
                    .font(.body.weight(.semibold))
                Text("Remove")
                    .font(.monoEyebrow)
                    .tracking(0.8)
            }
            .foregroundStyle(Color.parchment)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bordeaux)
        }
        .buttonStyle(.plain)
        // Hidden until at least a sliver of the action is revealed —
        // avoids capturing taps that fall outside the visible chip.
        .opacity(dragOffset < 0 ? 1 : 0)
        .accessibilityLabel("Remove from schedule")
    }
}
