import SwiftUI

/// Elevation tokens mirroring the web's `--shadow-elev-*` custom properties.
/// The tinted shadow colour (`rgba(35,24,21,...)`) ties shadows back to the
/// walnut text colour rather than pure black, so they read warmer on the
/// parchment background.
public enum Elevation {
    case elev1
    case elev2
    case elev3

    fileprivate var color: Color {
        Color(hex: 0x231815, opacity: opacity)
    }
    fileprivate var opacity: Double {
        switch self {
        case .elev1: 0.10
        case .elev2: 0.12
        case .elev3: 0.16
        }
    }
    fileprivate var radius: CGFloat {
        switch self {
        case .elev1: 2
        case .elev2: 8
        case .elev3: 16
        }
    }
    fileprivate var y: CGFloat {
        switch self {
        case .elev1: 1
        case .elev2: 4
        case .elev3: 12
        }
    }
}

public extension View {
    /// Apply one of the three named elevation shadows.
    func elevation(_ elevation: Elevation) -> some View {
        self.shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
    }
}
