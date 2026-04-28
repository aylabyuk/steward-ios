import Foundation

/// Classifies a Sunday meeting into the four shapes the card body
/// renders: a regular sacrament meeting (numbered speaker slots), a
/// fast Sunday (testimony stamp, no speakers), a stake conference, or
/// a general conference (both stake-wide / general-wide stamps, no
/// local program). Mirrors the web's `KIND_MAP` in
/// `src/features/schedule/utils/kindLabel.ts`.
public enum MeetingKind: String, Sendable, Equatable {
    case regular
    case fast
    case stake
    case general

    /// Decode from the permissive `Meeting.meetingType` string. Any value
    /// the iOS app doesn't recognise (a future type the web adds, an
    /// empty string, nil) falls back to `.regular` so the card stays
    /// rendered with the default speaker-slot layout.
    public init(rawType: String?) {
        switch rawType {
        case "fast":    self = .fast
        case "stake":   self = .stake
        case "general": self = .general
        default:        self = .regular
        }
    }

    /// `true` for kinds that replace the speaker list with a centered
    /// stamp (fast / stake / general). Prayer rows still render below
    /// the stamp regardless of `isSpecial`.
    public var isSpecial: Bool {
        self != .regular
    }

    /// Eyebrow label printed next to the stamp icon. `nil` for `.regular`
    /// because the regular card has no stamp.
    public var stampLabel: String? {
        switch self {
        case .regular: nil
        case .fast:    "Testimony meeting"
        case .stake:   "Stake-wide session"
        case .general: "General session"
        }
    }

    /// Italic-serif sentence that explains why there are no speakers.
    /// `nil` for `.regular`.
    public var stampDescription: String? {
        switch self {
        case .regular: nil
        case .fast:    "No assigned speakers — member testimonies."
        case .stake:   "No local program — stake-wide session."
        case .general: "No local program — general session."
        }
    }

    /// Tone for the stamp icon + label, reusing the same `StatusBadge.Tone`
    /// palette as the type-badge pill so the colour language stays
    /// unified across the schedule.
    public var stampTone: StatusBadge.Tone {
        switch self {
        case .regular: .neutral   // unused; `.regular` has no stamp
        case .fast:    .pending   // brass
        case .stake:   .destructive  // bordeaux
        case .general: .destructive  // bordeaux
        }
    }

    /// Whether the local ward picks any of the program — speakers,
    /// prayer-givers, hymns. Regular sacrament meetings have a full local
    /// program; fast Sundays still have local OP/CP prayers (members
    /// share testimonies in lieu of speakers); stake conference and
    /// general conference are run from outside the ward, so the card
    /// doesn't render OP/CP rows for those.
    ///
    /// Deviation from the web: `SundayCardSpecial` still shows prayer
    /// rows for stake/general. iOS hides them — there's no local prayer
    /// to assign, so the empty rows just confuse the bishop.
    public var hasLocalProgram: Bool {
        switch self {
        case .regular, .fast: true
        case .stake, .general: false
        }
    }
}
