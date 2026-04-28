import SwiftUI

/// Hero section used at the top of every feature screen. Mirrors the web
/// `AppBar` hero block (eyebrow + serif display title + italic-serif
/// description), but designed for native iOS so it scrolls with the content
/// and lets a glass-effect toolbar overlay handle stickiness above.
///
/// Usage:
/// ```swift
/// AppBarHeader(
///     eyebrow: "Ward administration",
///     title: "Schedule",
///     description: "Upcoming sacrament meetings."
/// )
/// ```
public struct AppBarHeader: View {
    public let eyebrow: String?
    public let title: String
    public let description: String?

    public init(eyebrow: String? = nil, title: String, description: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.monoEyebrow)
                    .tracking(1.6)
                    .foregroundStyle(Color.brassDeep)
                    .padding(.bottom, 2)
            }
            Text(title)
                .font(.displayHero)
                .foregroundStyle(Color.walnut)
            if let description {
                Text(description)
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut2)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s5)
    }
}

#Preview {
    VStack(spacing: 0) {
        AppBarHeader(
            eyebrow: "Ward administration",
            title: "Schedule",
            description: "Upcoming sacrament meetings."
        )
        Divider()
        AppBarHeader(title: "No description")
        Divider()
        AppBarHeader(eyebrow: "Settings", title: "Profile")
    }
    .background(Color.parchment)
}
