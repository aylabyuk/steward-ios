import Foundation
import SwiftUI

/// Mirror of the web's INVITATION_STATUSES at
/// `src/lib/types/meeting.ts:13-19`. Speakers and prayers share this
/// lifecycle — there is no separate SpeakerStatus enum; the web aliases
/// them on the same union type.
public enum InvitationStatus: String, CaseIterable, Sendable, Codable {
    case planned
    case invited
    case confirmed
    case declined

    /// Lenient decoder — case-insensitive, returns nil for unknown
    /// strings so a future web-side status doesn't crash the parse.
    /// Mirrors the way StatusBadge.Tone(rawStatus:) tolerates the
    /// backend (case-insensitive, falls back gracefully).
    public init?(rawString: String?) {
        guard let raw = rawString?.lowercased(), raw.isEmpty == false else { return nil }
        guard let match = InvitationStatus(rawValue: raw) else { return nil }
        self = match
    }

    /// Visual tone the row's status dot / pill should render. Single
    /// source of truth for the lifecycle → tone mapping; StatusBadge
    /// folds in non-invitation statuses (draft, approved, published)
    /// on top of this.
    public var tone: StatusBadge.Tone {
        switch self {
        case .planned:    .neutral
        case .invited:    .pending
        case .confirmed:  .success
        case .declined:   .destructive
        }
    }
}
