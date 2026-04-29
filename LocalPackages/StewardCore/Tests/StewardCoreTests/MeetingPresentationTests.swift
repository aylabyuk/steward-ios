import Foundation
import Testing
@testable import StewardCore

/// User-facing behaviour tests for the Meeting → row presentation logic.
/// Each test describes what a bishopric user sees on the schedule screen.

private let posix = Locale(identifier: "en_US_POSIX")

@Suite("Meeting type fallback — what the card looks like when no doc exists")
struct MeetingTypeFallbackTests {

    @Test("First Sunday of the month falls back to a fast Sunday")
    func firstSundayIsFast() {
        // 2026-05-03 was the first Sunday of May 2026.
        #expect(Meeting.fallbackType(forDate: "2026-05-03") == "fast")
        // 2026-04-26 was the LAST Sunday of April (day 26 > 7) — regular.
        #expect(Meeting.fallbackType(forDate: "2026-04-26") == "regular")
    }

    @Test("Other weeks of the month fall back to regular")
    func laterSundaysAreRegular() {
        #expect(Meeting.fallbackType(forDate: "2026-05-10") == "regular")
        #expect(Meeting.fallbackType(forDate: "2026-05-17") == "regular")
        #expect(Meeting.fallbackType(forDate: "2026-05-24") == "regular")
        #expect(Meeting.fallbackType(forDate: "2026-05-31") == "regular")
    }

    @Test("Unparseable date IDs default to regular so the row still renders")
    func unparseable() {
        #expect(Meeting.fallbackType(forDate: "garbage") == "regular")
    }
}

@Suite("Meeting card body — what the user reads inside each meeting card")
struct MeetingCardBodyTests {

    @Test("Fast Sundays mark the card as a testimony meeting")
    func fastIsTestimony() {
        #expect(Meeting(meetingType: "fast").isTestimonyMeeting)
        #expect(Meeting(meetingType: "regular").isTestimonyMeeting == false)
        #expect(Meeting(meetingType: nil).isTestimonyMeeting == false)
    }

    @Test("Opening + closing prayer assignees surface from the meeting doc")
    func prayerAssignees() throws {
        let json = """
        {
            "meetingType": "regular",
            "openingPrayer": { "person": { "name": "Sister Davis" } },
            "benediction":   { "person": { "name": "Brother Cole" } }
        }
        """.data(using: .utf8)!
        let meeting = try JSONDecoder().decode(Meeting.self, from: json)
        #expect(meeting.openingPrayerName == "Sister Davis")
        #expect(meeting.benedictionName == "Brother Cole")
    }

    @Test("Missing prayer assignments surface as nil so the UI can render 'Not assigned'")
    func unassignedPrayers() {
        let meeting = Meeting(meetingType: "regular")
        #expect(meeting.openingPrayerName == nil)
        #expect(meeting.benedictionName == nil)
    }

    @Test("An invited prayer's status round-trips off the inline Assignment so the row shows a brass dot")
    func prayerStatusRoundTrip() throws {
        // iOS deviation from the web: the inline Assignment now carries
        // a `status` field too (web stores prayer status only in the
        // post-invite `prayers/{role}` subcollection). See
        // docs/web-deviations.md for the rationale.
        let json = """
        {
            "meetingType": "regular",
            "openingPrayer": {
                "person": { "name": "Sister Davis", "email": "sd@example.com" },
                "confirmed": false,
                "status": "invited"
            },
            "benediction": {
                "person": { "name": "Brother Cole" },
                "confirmed": false,
                "status": "planned"
            }
        }
        """.data(using: .utf8)!
        let meeting = try JSONDecoder().decode(Meeting.self, from: json)
        #expect(meeting.openingPrayer?.status == "invited")
        #expect(meeting.benediction?.status == "planned")
        #expect(InvitationStatus(rawString: meeting.openingPrayer?.status)?.tone == .pending)
        #expect(InvitationStatus(rawString: meeting.benediction?.status)?.tone == .neutral)
    }

    @Test("A meeting decoded without a prayer status leaves the field nil so the legacy doc shape still loads")
    func prayerStatusBackcompat() throws {
        let json = """
        {
            "meetingType": "regular",
            "openingPrayer": { "person": { "name": "Sister Davis" } }
        }
        """.data(using: .utf8)!
        let meeting = try JSONDecoder().decode(Meeting.self, from: json)
        #expect(meeting.openingPrayer?.status == nil)
    }
}

@Suite("Schedule date formatting — what date string the user reads on a row")
struct ShortDateFormatterTests {

    @Test("YYYY-MM-DD parses into 'Wkd, MMM d' under the pinned locale")
    func happyPath() {
        // 2026-05-17 was a Sunday.
        #expect(
            ShortDateFormatter.shortDate(fromISO8601: "2026-05-17", locale: posix)
                == "Sun, May 17"
        )
    }

    @Test(
        "Multiple sample Sundays parse and format correctly",
        arguments: [
            (raw: "2026-04-26", expected: "Sun, Apr 26"),
            (raw: "2026-05-03", expected: "Sun, May 3"),
            (raw: "2026-12-13", expected: "Sun, Dec 13"),
        ]
    )
    func samples(raw: String, expected: String) {
        #expect(ShortDateFormatter.shortDate(fromISO8601: raw, locale: posix) == expected)
    }

    @Test("Unparseable IDs fall back to the raw string so the row still renders")
    func parseFailure() {
        #expect(ShortDateFormatter.shortDate(fromISO8601: "not-a-date", locale: posix) == "not-a-date")
    }

    @Test("monthYear formatting renders 'Month YYYY' for valid IDs")
    func monthYear() {
        #expect(ShortDateFormatter.monthYear(fromISO8601: "2026-05-17", locale: posix) == "May 2026")
        #expect(ShortDateFormatter.monthYear(fromISO8601: "2026-12-27", locale: posix) == "December 2026")
    }

    @Test("monthYear returns nil for unparseable IDs (caller decides fallback)")
    func monthYearFailure() {
        #expect(ShortDateFormatter.monthYear(fromISO8601: "garbage", locale: posix) == nil)
    }
}

@Suite("Schedule sections — month grouping + ordering the user sees")
struct ScheduleSectionsTests {

    private func item(_ id: String) -> CollectionItem<Meeting> {
        CollectionItem(id: id, data: Meeting())
    }

    @Test("Empty input yields no sections")
    func empty() {
        #expect(ScheduleSections.groupByMonth([], locale: posix).isEmpty)
    }

    @Test("Most recent month appears first; meetings inside descend by date")
    func descendingOrder() {
        let sections = ScheduleSections.groupByMonth(
            [
                item("2026-04-26"),
                item("2026-05-17"),
                item("2026-05-03"),
                item("2026-05-10"),
            ],
            locale: posix
        )

        // Two sections: May 2026 first (more recent), then April 2026.
        #expect(sections.map(\.title) == ["May 2026", "April 2026"])
        // Inside May, dates descend.
        #expect(sections[0].items.map(\.id) == ["2026-05-17", "2026-05-10", "2026-05-03"])
        // April has just the one.
        #expect(sections[1].items.map(\.id) == ["2026-04-26"])
    }

    @Test("Items with non-ISO IDs collapse into a single 'Other' section")
    func unparseable() {
        let sections = ScheduleSections.groupByMonth(
            [item("2026-05-17"), item("backfill-job"), item("orphan")],
            locale: posix
        )
        #expect(sections.contains { $0.title == "Other" })
        let other = try? #require(sections.first { $0.title == "Other" })
        // "backfill-job" > "orphan" lexicographically, so backfill comes first.
        #expect(other?.items.map(\.id) == ["orphan", "backfill-job"])
    }

    @Test("Sections survive a duplicate-month edge case without flickering")
    func sameMonthMultipleEntries() {
        let sections = ScheduleSections.groupByMonth(
            [
                item("2026-05-31"), item("2026-05-24"),
                item("2026-05-17"), item("2026-05-10"),
                item("2026-05-03"),
            ],
            locale: posix
        )
        #expect(sections.count == 1)
        #expect(sections[0].title == "May 2026")
        #expect(sections[0].items.count == 5)
    }
}
