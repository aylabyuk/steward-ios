import Foundation
import Testing
@testable import StewardCore

/// User-facing behaviour tests for the relative-time pill on each meeting
/// card ("IN 5 DAYS", "IN 2 WEEKS", etc.). Mirrors the web's MobileSundayBlock
/// "in N days" microcopy beside the date headline.

private let posix = Locale(identifier: "en_US_POSIX")

private func today(_ raw: String) -> Date {
    let strategy = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
    return try! Date(raw, strategy: strategy)
}

@Suite("Relative day label — what the user reads beside the meeting date")
struct RelativeDayLabelTests {

    @Test("Same-day meetings read 'Today'")
    func sameDay() {
        let label = RelativeDayLabel.string(
            fromISO8601: "2026-05-03",
            today: today("2026-05-03"),
            locale: posix
        )
        #expect(label == "Today")
    }

    @Test("Day-after meetings read 'Tomorrow'")
    func tomorrow() {
        let label = RelativeDayLabel.string(
            fromISO8601: "2026-05-04",
            today: today("2026-05-03"),
            locale: posix
        )
        #expect(label == "Tomorrow")
    }

    @Test("Day-before meetings read 'Yesterday'")
    func yesterday() {
        let label = RelativeDayLabel.string(
            fromISO8601: "2026-05-02",
            today: today("2026-05-03"),
            locale: posix
        )
        #expect(label == "Yesterday")
    }

    @Test(
        "2–6 days ahead read 'In N days' (singular vs plural handled)",
        arguments: [
            (target: "2026-05-05", today: "2026-05-03", expected: "In 2 days"),
            (target: "2026-05-08", today: "2026-05-03", expected: "In 5 days"),
            (target: "2026-05-09", today: "2026-05-03", expected: "In 6 days"),
        ]
    )
    func nearFuture(target: String, today raw: String, expected: String) {
        #expect(
            RelativeDayLabel.string(fromISO8601: target, today: today(raw), locale: posix)
                == expected
        )
    }

    @Test(
        "7+ days ahead roll up to weeks until ~60 days, then months",
        arguments: [
            (target: "2026-05-10", today: "2026-05-03", expected: "In 1 week"),
            (target: "2026-05-17", today: "2026-05-03", expected: "In 2 weeks"),
            (target: "2026-05-24", today: "2026-05-03", expected: "In 3 weeks"),
            (target: "2026-07-05", today: "2026-05-03", expected: "In 2 months"),
        ]
    )
    func farFuture(target: String, today raw: String, expected: String) {
        #expect(
            RelativeDayLabel.string(fromISO8601: target, today: today(raw), locale: posix)
                == expected
        )
    }

    @Test(
        "Past dates mirror the future scale ('N days ago', 'N weeks ago')",
        arguments: [
            (target: "2026-04-30", today: "2026-05-03", expected: "3 days ago"),
            (target: "2026-04-26", today: "2026-05-03", expected: "1 week ago"),
            (target: "2026-04-19", today: "2026-05-03", expected: "2 weeks ago"),
        ]
    )
    func past(target: String, today raw: String, expected: String) {
        #expect(
            RelativeDayLabel.string(fromISO8601: target, today: today(raw), locale: posix)
                == expected
        )
    }

    @Test("Unparseable date IDs return nil so the UI can omit the pill")
    func unparseable() {
        let label = RelativeDayLabel.string(
            fromISO8601: "not-a-date",
            today: today("2026-05-03"),
            locale: posix
        )
        #expect(label == nil)
    }
}

@Suite("Schedule date headline — 'May 3' style (no weekday)")
struct ShortDateMonthDayTests {

    @Test(
        "Renders 'MMM d' from a YYYY-MM-DD doc ID",
        arguments: [
            (raw: "2026-05-03", expected: "May 3"),
            (raw: "2026-05-17", expected: "May 17"),
            (raw: "2026-12-13", expected: "Dec 13"),
        ]
    )
    func happyPath(raw: String, expected: String) {
        #expect(
            ShortDateFormatter.monthDay(fromISO8601: raw, locale: posix) == expected
        )
    }

    @Test("Unparseable input falls back to the raw string so the row still renders")
    func parseFailure() {
        #expect(ShortDateFormatter.monthDay(fromISO8601: "garbage", locale: posix) == "garbage")
    }
}
