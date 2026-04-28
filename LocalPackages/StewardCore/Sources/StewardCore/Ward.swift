import Foundation

/// The minimal shape of a `wards/{wardId}` document — just enough for the
/// dark top bar to render the human ward name. Mirrors the web's `wardSchema`
/// in `src/lib/types/`; only the fields the iOS app reads are typed here.
public struct Ward: Decodable, Equatable, Sendable {
    public let name: String?

    public init(name: String?) {
        self.name = name
    }

    /// What the top bar displays. Returns the human ward name when the doc
    /// is loaded and has a non-blank `name`; otherwise falls back to the
    /// wardId so the bar always renders something stable rather than
    /// flickering between empty and resolved.
    public static func displayTitle(ward: Ward?, wardId: String) -> String {
        if let name = ward?.name?.trimmingCharacters(in: .whitespaces),
           name.isEmpty == false {
            return name
        }
        return wardId
    }
}
