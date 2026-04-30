import Foundation

/// Codable mirror of a subset of `sacramentMeetingSchema` from the web at
/// `src/lib/types/meeting.ts`. All fields are optional so a partially-populated
/// document (or one with new fields the iOS app doesn't know about yet) decodes
/// cleanly. The full schema is far richer — flesh out as Phase 1 features land.
public struct Meeting: Codable, Sendable, Equatable {
    public let meetingType: String?
    public let status: String?
    public let conducting: Assignment?
    public let presiding: Assignment?
    public let openingPrayer: Assignment?
    public let benediction: Assignment?
    public let openingHymn: Hymn?
    public let sacramentHymn: Hymn?
    public let closingHymn: Hymn?

    public init(
        meetingType: String? = nil,
        status: String? = nil,
        conducting: Assignment? = nil,
        presiding: Assignment? = nil,
        openingPrayer: Assignment? = nil,
        benediction: Assignment? = nil,
        openingHymn: Hymn? = nil,
        sacramentHymn: Hymn? = nil,
        closingHymn: Hymn? = nil
    ) {
        self.meetingType = meetingType
        self.status = status
        self.conducting = conducting
        self.presiding = presiding
        self.openingPrayer = openingPrayer
        self.benediction = benediction
        self.openingHymn = openingHymn
        self.sacramentHymn = sacramentHymn
        self.closingHymn = closingHymn
    }

    public struct Assignment: Codable, Sendable, Equatable {
        public let person: Person?
        public let confirmed: Bool?
        /// Lifecycle string — `"planned" | "invited" | "confirmed" | "declined"`.
        /// **iOS-side deviation from the web schema.** The web only carries
        /// status on the post-invite `prayers/{role}` subcollection doc;
        /// iOS additionally writes it inline so v1 doesn't need a parallel
        /// subcollection writer + dual-source-of-truth read path. Web's
        /// lenient Zod ignores the extra field. Stored raw to tolerate
        /// future server-side states; UI maps via `InvitationStatus(rawString:)`.
        public let status: String?
        /// `wards/{wardId}/speakerInvitations/{invitationId}` doc id —
        /// stamped after `sendSpeakerInvitation` returns successfully so
        /// the chat sheet can fetch the invitation snapshot. Absent for
        /// planned prayers and pre-callable rollout docs.
        public let invitationId: String?

        public init(
            person: Person? = nil,
            confirmed: Bool? = nil,
            status: String? = nil,
            invitationId: String? = nil
        ) {
            self.person = person
            self.confirmed = confirmed
            self.status = status
            self.invitationId = invitationId
        }
    }

    public struct Person: Codable, Sendable, Equatable {
        public let name: String?
        public let email: String?
        public let phone: String?
        public init(name: String? = nil, email: String? = nil, phone: String? = nil) {
            self.name = name
            self.email = email
            self.phone = phone
        }
    }

    public struct Hymn: Codable, Sendable, Equatable {
        public let number: Int?
        public let title: String?
        public init(number: Int? = nil, title: String? = nil) {
            self.number = number
            self.title = title
        }
    }
}

public extension Meeting {
    /// Display label for the meeting type. Falls back to a humanised form of
    /// the raw string so unknown types still render something.
    var meetingTypeLabel: String {
        switch meetingType {
        case "regular": "Sacrament"
        case "fast": "Fast & Testimony"
        case "stake": "Stake Conference"
        case "general": "General Conference"
        case let other?: other.capitalized
        case nil: "Meeting"
        }
    }

    var conductingName: String? {
        conducting?.person?.name
    }

    var presidingName: String? {
        presiding?.person?.name
    }

    var openingPrayerName: String? {
        openingPrayer?.person?.name
    }

    var benedictionName: String? {
        benediction?.person?.name
    }

    /// `true` when the card should render the "TESTIMONY MEETING — no
    /// assigned speakers, member testimonies" eyebrow instead of a speaker
    /// list. Mirrors the web's `isTestimonyMeeting(meeting)` helper.
    var isTestimonyMeeting: Bool {
        meetingType == "fast"
    }

    /// Label for the ⋯-menu's "plan / view" entry. Reads "Plan Sacrament
    /// Meeting" when no doc has been written yet, "View Meeting" once one
    /// exists. Pure helper so the menu can render the right copy
    /// reactively as the meeting subscription resolves.
    static func planActionLabel(meeting: Meeting?) -> String {
        meeting == nil ? "Plan Sacrament Meeting" : "View Meeting"
    }

    /// Inferred type for a Sunday slot when no meeting doc exists yet.
    /// First Sunday of the month → "fast", everything else → "regular".
    /// Mirrors the web's `defaultMeetingType` (minus the
    /// `nonMeetingSundays` override, which lives in ward settings we
    /// don't read yet — TODO when ward settings ship). Falls back to
    /// "regular" for unparseable IDs so the row still renders.
    static func fallbackType(forDate isoDate: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let strategy = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        guard let date = try? Date(isoDate, strategy: strategy) else {
            return "regular"
        }
        let comps = calendar.dateComponents([.weekday, .day], from: date)
        if comps.weekday == 1, let day = comps.day, day <= 7 {
            return "fast"
        }
        return "regular"
    }

}

public enum ShortDateFormatter {
    /// Parse `"2026-05-17"` (Firestore meeting doc IDs) and render
    /// `"Sun, May 17"`. Falls back to the raw input string when parsing
    /// fails so we don't render an empty cell.
    ///
    /// Doc IDs are *civil dates* (a calendar day, not a timestamp), so we
    /// parse as UTC midnight and format with the same UTC timezone — that
    /// way "2026-05-17" reads as May 17 everywhere regardless of the
    /// device's local zone. Locale is pinned to `en_US_POSIX` by default
    /// so tests stay deterministic across machines; the production call
    /// site passes the user's current locale.
    public static func shortDate(
        fromISO8601 raw: String,
        locale: Locale = .current
    ) -> String {
        guard let parsed = parseCivilDate(raw) else { return raw }
        var style = Date.FormatStyle()
            .weekday(.abbreviated)
            .month(.abbreviated)
            .day()
            .locale(locale)
        style.timeZone = .gmt
        return parsed.formatted(style)
    }

    /// Render the month-section title for a given doc ID:
    /// `"2026-05-17"` → `"May 2026"` (locale-aware, UTC-pinned for the
    /// same civil-date rationale as `shortDate`).
    public static func monthYear(
        fromISO8601 raw: String,
        locale: Locale = .current
    ) -> String? {
        guard let parsed = parseCivilDate(raw) else { return nil }
        var style = Date.FormatStyle()
            .month(.wide)
            .year()
            .locale(locale)
        style.timeZone = .gmt
        return parsed.formatted(style)
    }

    /// Render the meeting card headline date: `"2026-05-03"` → `"May 3"`
    /// (no weekday, mirrors the web's MobileSundayBlock card title). Falls
    /// back to the raw string on parse failure so a row never blanks out.
    public static func monthDay(
        fromISO8601 raw: String,
        locale: Locale = .current
    ) -> String {
        guard let parsed = parseCivilDate(raw) else { return raw }
        var style = Date.FormatStyle()
            .month(.abbreviated)
            .day()
            .locale(locale)
        style.timeZone = .gmt
        return parsed.formatted(style)
    }

    private static func parseCivilDate(_ raw: String) -> Date? {
        let strategy = Date.ISO8601FormatStyle(timeZone: .gmt)
            .year().month().day()
        return try? Date(raw, strategy: strategy)
    }
}

public enum ScheduleSections {
    /// Wraps a CollectionItem<Meeting> list into month-grouped sections,
    /// preserving the descending-by-id ordering (lexicographic on YYYY-MM-DD
    /// = chronological) for both sections and items inside. Items whose IDs
    /// don't parse as ISO dates collapse into a single trailing "Other"
    /// section, matching the web's `groupByMonth` permissive behaviour.
    public static func groupByMonth(
        _ items: [CollectionItem<Meeting>],
        locale: Locale = .current
    ) -> [MonthSection] {
        let sorted = items.sorted { $0.id > $1.id }
        var seen: Set<String> = []
        var ordered: [MonthSection] = []
        for item in sorted {
            let title = ShortDateFormatter.monthYear(fromISO8601: item.id, locale: locale)
                ?? "Other"
            if seen.insert(title).inserted {
                ordered.append(MonthSection(title: title, items: []))
            }
            ordered[ordered.count - 1].items.append(item)
        }
        return ordered
    }
}

public struct MonthSection: Sendable, Equatable {
    public let title: String
    public var items: [CollectionItem<Meeting>]

    public init(title: String, items: [CollectionItem<Meeting>]) {
        self.title = title
        self.items = items
    }
}
