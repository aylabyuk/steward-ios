import Foundation
import Testing
@testable import StewardCore

/// What the speaker reads in place of a deleted bishop message.
/// iOS deviation from the web — the web silently removes the bubble
/// and leaves a gap in the timeline. iOS posts a tombstone system
/// notice so the speaker sees that *something* happened, who did it,
/// and roughly when. The copy is sentence-style and pinned with
/// parameterized tests so the audit string can't drift unintentionally.
@Suite("DeletedMessageNotice — what shows up in place of a deleted bubble")
struct DeletedMessageNoticeTests {

    // 2026-04-28 18:00:00 UTC — pin for deterministic month/day rendering.
    private let april28: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 28
        components.hour = 18
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    private let posix = Locale(identifier: "en_US_POSIX")
    private let utc = TimeZone(identifier: "UTC")!

    @Test("Named removal — `Message removed by Bishop John · Apr 28.`")
    func namedRemoval() {
        let body = DeletedMessageNotice.body(
            removedBy: "Bishop John",
            on: april28,
            locale: posix,
            timeZone: utc
        )
        #expect(body == "Message removed by Bishop John \u{00B7} Apr 28.")
    }

    @Test(
        "Missing / empty name falls back to actor-less copy — same date suffix",
        arguments: [
            (label: "nil",        input: nil as String?),
            (label: "empty",      input: ""),
            (label: "whitespace", input: "   "),
        ]
    )
    func actorlessFallback(label: String, input: String?) {
        let body = DeletedMessageNotice.body(
            removedBy: input,
            on: april28,
            locale: posix,
            timeZone: utc
        )
        #expect(body == "Message removed \u{00B7} Apr 28.", "[\(label)] should fall back to no-actor copy")
    }

    @Test("Names round-trip through whitespace trimming")
    func nameTrimsWhitespace() {
        let body = DeletedMessageNotice.body(
            removedBy: "  Bishop John  ",
            on: april28,
            locale: posix,
            timeZone: utc
        )
        #expect(body == "Message removed by Bishop John \u{00B7} Apr 28.")
    }

    @Test("Date formatting respects the caller's timezone — late-UTC stays Apr 28 in ET")
    func timezoneSensitiveDate() {
        // 2026-04-29 02:00 UTC = 2026-04-28 22:00 America/New_York.
        // The bishop deleted late-evening ET; the notice should read
        // Apr 28, not Apr 29.
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 29
        components.hour = 2
        components.timeZone = TimeZone(identifier: "UTC")
        let lateUTC = Calendar(identifier: .gregorian).date(from: components)!

        let body = DeletedMessageNotice.body(
            removedBy: "Bishop John",
            on: lateUTC,
            locale: posix,
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        #expect(body == "Message removed by Bishop John \u{00B7} Apr 28.")
    }
}
