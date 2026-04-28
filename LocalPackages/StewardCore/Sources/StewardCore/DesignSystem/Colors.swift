import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Design tokens mirroring the web app's `@theme` palette at
/// `/Users/oriel/projects/steward/src/styles/index.css`. The web is light-only;
/// the dark variants below are derived to keep the warm walnut/parchment/brass
/// brand identity rather than collapsing to generic charcoal.
///
/// Each token resolves dynamically based on `UITraitCollection.userInterfaceStyle`,
/// so `Color.walnut` adapts automatically when the user toggles dark mode.
public extension Color {

    // MARK: Backgrounds (parchment family)

    /// Default page background. Web `--color-parchment`.
    static let parchment = dynamic(light: 0xFBF6EE, dark: 0x1C1410)
    /// Sunken background, card-on-card. Web `--color-parchment-2`.
    static let parchment2 = dynamic(light: 0xF4ECDC, dark: 0x241A14)
    /// Subtle dividers / depth wells. Web `--color-parchment-3`.
    static let parchment3 = dynamic(light: 0xE9DCC2, dark: 0x2E221A)

    // MARK: Surfaces

    /// Card surface — slightly warmer than pure white. Web `--color-chalk`.
    static let chalk = dynamic(light: 0xFFFDF7, dark: 0x2A1F17)

    // MARK: Text (walnut family)

    /// Primary text. Web `--color-walnut`.
    static let walnut = dynamic(light: 0x3B2A22, dark: 0xFBF6EE)
    /// Secondary text. Web `--color-walnut-2`.
    static let walnut2 = dynamic(light: 0x5A4636, dark: 0xCDBFA8)
    /// Tertiary text. Web `--color-walnut-3`.
    static let walnut3 = dynamic(light: 0x8A7460, dark: 0x9B8A72)
    /// Strongest contrast text. Web `--color-walnut-ink`.
    static let walnutInk = dynamic(light: 0x231815, dark: 0xFFFFFF)

    // MARK: Brand reds (bordeaux family)

    /// Primary CTA, destructive accent. Web `--color-bordeaux`.
    static let bordeaux = dynamic(light: 0x8B2E2A, dark: 0xC47570)
    /// CTA pressed. Web `--color-bordeaux-deep`.
    static let bordeauxDeep = dynamic(light: 0x6B1F1C, dark: 0xA55050)
    /// Light bordeaux backgrounds (badges). Web `--color-bordeaux-soft`.
    static let bordeauxSoft = dynamic(light: 0xB65449, dark: 0x3B1F1D)

    // MARK: Brand golds (brass family)

    /// Accent / eyebrow labels. Web `--color-brass`.
    static let brass = dynamic(light: 0xC89B5A, dark: 0xE0BE87)
    /// Soft brass fills. Web `--color-brass-soft`.
    static let brassSoft = dynamic(light: 0xE0BE87, dark: 0x3D2E1C)
    /// Brass on dark / strong brass labels. Web `--color-brass-deep`.
    static let brassDeep = dynamic(light: 0x8E6A36, dark: 0xC89B5A)

    // MARK: Borders

    /// Default border. Web `--color-border`.
    static let border = dynamic(light: 0xD9C9A8, dark: 0x3D2F24)
    /// Emphasised border. Web `--color-border-strong`.
    static let borderStrong = dynamic(light: 0xB99E6E, dark: 0x5A4636)

    // MARK: Status

    /// Success text. Web `--color-success`.
    static let success = dynamic(light: 0x4E6B3A, dark: 0x9BB583)
    /// Success badge fill. Web `--color-success-soft`.
    static let successSoft = dynamic(light: 0xE2EAD3, dark: 0x1F3220)

    /// Warning text. Web `--color-warning`.
    static let warning = dynamic(light: 0xB97A19, dark: 0xE0B067)
    /// Warning badge fill. Web `--color-warning-soft`.
    static let warningSoft = dynamic(light: 0xF6E6C4, dark: 0x3A2C14)

    /// Destructive / declined badge fill. Web `--color-danger-soft`.
    static let dangerSoft = dynamic(light: 0xF3DAD5, dark: 0x3A1F1D)

    /// Informational badge fill. Web `--color-info-soft`.
    static let infoSoft = dynamic(light: 0xDCE5EB, dark: 0x1D2A32)
}

// MARK: - Hex + dynamic-light/dark helpers

public extension Color {
    /// Initialize from an integer hex literal: `Color(hex: 0xFBF6EE)`.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

internal extension Color {
    /// Build a colour that resolves to one hex in light mode and another in dark.
    /// On iOS this routes through `UIColor.dynamicProvider` so it adapts when
    /// `UITraitCollection.userInterfaceStyle` flips. On macOS it falls back to
    /// the light value (the package supports macOS for `swift test`, but the
    /// app only runs on iOS).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #else
        return Color(hex: light)
        #endif
    }
}

#if canImport(UIKit)
public extension UIColor {
    /// Initialize from an integer hex literal: `UIColor(hex: 0xFBF6EE)`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >>  8) & 0xFF) / 255.0,
            blue: CGFloat( hex        & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
#endif
