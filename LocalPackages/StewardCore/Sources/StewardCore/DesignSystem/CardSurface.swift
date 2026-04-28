import SwiftUI

public extension View {
    /// Apply the chalk-on-parchment card surface used by login forms,
    /// settings sections, and any "lift this content out of the page"
    /// container. Mirrors the web pattern:
    /// `rounded-lg border border-border bg-chalk p-6 shadow-sm`.
    func cardSurface(padding: CGFloat = Spacing.s6, cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(CardSurfaceModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

private struct CardSurfaceModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.chalk, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
            .elevation(.elev1)
    }
}

#Preview {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card title")
                .font(.bodyEmphasis)
                .foregroundStyle(Color.walnut)
            Text("This is a card surface — chalk on parchment with a thin border and elev1 shadow.")
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
        }
        .cardSurface()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.parchment)
}
