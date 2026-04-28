import SwiftUI

/// Font tokens mirroring the web app's typography stack:
///   - **Newsreader** (serif) for display headlines and italic asides.
///     Web uses `font-display`; mapped to `.display(...)` and `.serifAside`.
///   - **Inter Variable** (sans) for body copy.
///     Web uses `font-sans`; mapped to `.sans(...)` and `.bodyDefault` etc.
///   - **IBM Plex Mono** for eyebrow labels, status pills, and slot numbers.
///     Web uses `font-mono`; mapped to `.mono(...)` and `.monoEyebrow` etc.
///
/// PostScript family names verified against `FontAudit` output after bundling:
///   - `Newsreader`        — serif variable font, exposes Roman + Italic axes
///   - `Inter Variable`    — sans variable font
///   - `IBM Plex Mono`     — monospace, regular + medium + italic
///
/// All three are bundled at `steward-ios/Resources/Fonts/` and registered via
/// `UIAppFonts` in `Info.plist`. See the bundled `LICENSES.md` for OFL
/// attribution.

public extension Font {

    // MARK: Family lookups

    /// Newsreader (serif). Use for display headlines and italic asides.
    /// Pass a weight via `.weight()` modifier; the variable axis picks the
    /// right master.
    static func display(_ size: CGFloat, weight: Weight = .semibold) -> Font {
        .custom("Newsreader", size: size).weight(weight)
    }

    /// Newsreader Italic. Specifying the italic family-named instance via
    /// PostScript so the italic axis is honoured even when callers don't
    /// chain `.italic()`.
    static func displayItalic(_ size: CGFloat) -> Font {
        .custom("NewsreaderItalic-Regular", size: size)
    }

    /// Inter Variable (sans). Default body face.
    static func sans(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .custom("Inter Variable", size: size).weight(weight)
    }

    /// IBM Plex Mono. Use for eyebrow labels, status pills, slot numbers.
    static func mono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .custom("IBM Plex Mono", size: size).weight(weight)
    }

    // MARK: Pre-baked styles
    // Names mirror semantic web roles (`@layer base` plus feature components).
    // Keep this list small — adding ad-hoc sizes per screen breaks rhythm.

    /// h1-equivalent for hero screens (Login, Schedule).
    /// Web `text-[1.75rem] font-semibold` on Newsreader.
    static let displayHero = Font.display(28, weight: .semibold)

    /// h2-equivalent for sticky date headers in the schedule list.
    /// Web `text-xl font-semibold` on Newsreader.
    static let displaySection = Font.display(20, weight: .semibold)

    /// Standalone login title — slightly larger than displayHero.
    /// Web shows the login `<h1>Steward</h1>` at `text-xl` but on iOS we
    /// use the available room for a more confident hero.
    static let displayLogin = Font.display(34, weight: .semibold)

    /// Default body text. Web `text-base text-walnut`.
    static let bodyDefault = Font.sans(16, weight: .regular)

    /// Smaller body / dense rows. Web `text-sm`.
    static let bodySmall = Font.sans(14, weight: .regular)

    /// Names, headings inside lists. Web `text-sm font-semibold` on speakers.
    static let bodyEmphasis = Font.sans(14, weight: .semibold)

    /// Italic serif aside used for descriptions and topic lines.
    /// Web `font-serif italic text-sm` walnut-2.
    static let serifAside = Font.displayItalic(14.5)

    /// Small-caps eyebrow label. Web `font-mono text-[10.5px]
    /// uppercase tracking-[0.16em]` — apply `.tracking(1.6)` at usage site
    /// since `Font` doesn't carry tracking on its own.
    static let monoEyebrow = Font.mono(10.5, weight: .medium)

    /// Status pill / slot number text. Web `font-mono text-[9.5px]
    /// uppercase tracking-[0.12em]` — apply `.tracking(1.2)` at usage.
    static let monoMicro = Font.mono(9.5, weight: .medium)
}
