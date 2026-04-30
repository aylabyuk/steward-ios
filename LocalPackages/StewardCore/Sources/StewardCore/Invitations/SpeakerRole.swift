import Foundation

/// Mirror of the web's SPEAKER_ROLES at
/// `src/lib/types/meeting.ts:21-23`. Raw values match the strings the
/// web stores in Firestore — when iOS encodes a speaker doc, this enum's
/// `rawValue` is what lands on `wards/.../speakers/{id}.role`.
public enum SpeakerRole: String, CaseIterable, Hashable, Sendable, Codable {
    case member       = "Member"
    case youth        = "Youth"
    case highCouncil  = "High Council"
    case visiting     = "Visiting"

    /// What the picker shows. Same as the raw value today (no separate
    /// localization yet); kept as a property so the UI binds to a
    /// stable surface and we can swap in NSLocalizedString later
    /// without touching call sites.
    public var displayName: String { rawValue }
}
