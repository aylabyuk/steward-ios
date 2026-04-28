import CoreGraphics

/// Corner radius scale mirroring the web's `--radius-*` custom properties.
public enum Radius {
    public static let sm: CGFloat = 3      // --radius-sm
    public static let `default`: CGFloat = 6 // --radius
    public static let lg: CGFloat = 10     // --radius-lg
    public static let xl: CGFloat = 16     // --radius-xl
    /// Capsule-style pill. Use `.capsule` shape directly when possible.
    public static let pill: CGFloat = 999  // --radius-pill
}
