import Foundation

/// Which empty slot the bishopric tapped on the schedule. Drives the
/// form fields shown, the assign-button copy, and the {{prayerType}}
/// variable in the rendered letter. Speakers and the two prayer roles
/// all flow through the same form so layout / validation stay
/// deduplicated; this enum is the conditional branch.
public enum SlotKind: String, Sendable, Hashable, Codable {
    case speaker
    case openingPrayer
    case benediction

    /// Copy on the tappable pill that replaces "Not assigned" on the
    /// schedule row. The pill is the user's only entry point into the
    /// flow, so the verb has to read as an action, not a label.
    public var assignButtonLabel: String {
        switch self {
        case .speaker:        "Assign Speaker"
        case .openingPrayer:  "Assign Opening Prayer"
        case .benediction:    "Assign Closing Prayer"
        }
    }

    /// Title of the pushed form page. Same copy as the button so the
    /// destination reads like the action the user just took.
    public var formTitle: String {
        assignButtonLabel
    }

    /// Resolves to the {{prayerType}} variable in the prayer letter
    /// template. `nil` for speakers (their letters don't reference it).
    public var prayerType: String? {
        switch self {
        case .speaker:        nil
        case .openingPrayer:  "Opening Prayer"
        case .benediction:    "Benediction"
        }
    }

    public var isPrayer: Bool {
        prayerType != nil
    }

    /// Noun for the assignee in user-facing copy — "speaker" /
    /// "prayer giver". Used by `BannerView` and
    /// `InvitationStatusMirror` to phrase status messages so a prayer
    /// chat doesn't read as speaker-flavoured. iOS deviation — see
    /// `docs/web-deviations.md`.
    public var assigneeNoun: String {
        switch self {
        case .speaker:                       "speaker"
        case .openingPrayer, .benediction:   "prayer giver"
        }
    }

    /// Action verb describing what the assignee will do at the
    /// meeting — slots into "thank you for {action} on Sunday…"
    /// system messages.
    public var assigneeAction: String {
        switch self {
        case .speaker:                       "speaking"
        case .openingPrayer, .benediction:   "offering the prayer"
        }
    }
}
