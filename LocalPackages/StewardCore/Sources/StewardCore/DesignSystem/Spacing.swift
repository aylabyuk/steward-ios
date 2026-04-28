import CoreGraphics

/// Spacing scale mirroring the web's `--spacing-*` custom properties.
/// Use these instead of magic numbers so the rhythm stays in sync between
/// platforms when designers tweak the scale.
public enum Spacing {
    public static let s1: CGFloat = 4    // --spacing-1
    public static let s2: CGFloat = 8    // --spacing-2
    public static let s3: CGFloat = 12   // --spacing-3
    public static let s4: CGFloat = 16   // --spacing-4
    public static let s5: CGFloat = 20   // --spacing-5
    public static let s6: CGFloat = 24   // --spacing-6
    public static let s8: CGFloat = 32   // --spacing-8
    public static let s10: CGFloat = 40  // --spacing-10
    public static let s12: CGFloat = 48  // --spacing-12
    public static let s16: CGFloat = 64  // --spacing-16
    public static let s20: CGFloat = 80  // --spacing-20
    public static let s24: CGFloat = 96  // --spacing-24
}
