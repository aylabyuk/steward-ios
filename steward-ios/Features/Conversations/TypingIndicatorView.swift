import SwiftUI
import StewardCore

/// Three-dot typing indicator with the speaker's display name. Mirrors
/// the web's `TypingIndicator.tsx`:
///   * Empty identities → renders nothing.
///   * 1 person → "Sister Daisy is typing…"
///   * 2 people → "Alice and Bob are typing…"
///   * 3+ → "Alice and 2 others are typing…"
struct TypingIndicatorView: View {
    let identities: Set<String>
    let authors: [String: AuthorInfo]

    @State private var pulse: Bool = false

    var body: some View {
        if identities.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: Spacing.s2) {
                Text(label)
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut3)
                dots
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    pulse.toggle()
                }
            }
        }
    }

    private var label: String {
        let names = identities.compactMap { authors[$0]?.displayName }
        let resolved = names.isEmpty ? identities.map { _ in "Someone" } : names
        switch resolved.count {
        case 1: return "\(resolved[0]) is typing"
        case 2: return "\(resolved[0]) and \(resolved[1]) are typing"
        default:
            let first = resolved[0]
            return "\(first) and \(resolved.count - 1) others are typing"
        }
    }

    private var dots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.walnut3)
                    .frame(width: 4, height: 4)
                    .opacity(pulse ? 0.3 : 0.9)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: pulse
                    )
            }
        }
    }
}
