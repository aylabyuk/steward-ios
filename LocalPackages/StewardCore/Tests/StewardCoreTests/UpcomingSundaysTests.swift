import Foundation
import Testing
@testable import StewardCore

private func date(_ raw: String) -> Date {
    let strategy = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
    return try! Date(raw, strategy: strategy)
}

@Suite("Upcoming Sundays — what dates the schedule shows for the next N weeks")
struct UpcomingSundaysTests {

    @Test("Today=Sunday → first slot is today")
    func todayIsSunday() {
        let dates = UpcomingSundays.next(from: date("2026-04-26"), weeks: 1)
        #expect(dates == ["2026-04-26"]) // 2026-04-26 was a Sunday
    }

    @Test("Today=Tue → first slot is the next Sunday")
    func midweek() {
        let dates = UpcomingSundays.next(from: date("2026-04-28"), weeks: 1)
        #expect(dates == ["2026-05-03"]) // next Sunday after Tuesday 2026-04-28
    }

    @Test("Returns N Sundays in ascending order, week-spaced")
    func ascendingOrder() {
        let dates = UpcomingSundays.next(from: date("2026-04-28"), weeks: 4)
        #expect(dates == ["2026-05-03", "2026-05-10", "2026-05-17", "2026-05-24"])
    }

    @Test("weeks=0 yields no dates")
    func zeroWeeks() {
        #expect(UpcomingSundays.next(from: date("2026-04-28"), weeks: 0).isEmpty)
    }

    @Test("Negative weeks clamps to 0 (defensive — caller bug shouldn't crash)")
    func negativeWeeks() {
        #expect(UpcomingSundays.next(from: date("2026-04-28"), weeks: -3).isEmpty)
    }
}

@Suite("Speaker slot padding — how many rows the user reads inside a card")
struct SpeakerSlotPaddingTests {

    private func item(id: String, order: Int? = nil) -> CollectionItem<Speaker> {
        CollectionItem(id: id, data: Speaker(name: id, order: order))
    }

    @Test("Empty roster yields N empty placeholder slots so the bishop sees the gap")
    func empty() {
        let slots = Speaker.slots([], minSlotCount: 4)
        #expect(slots.count == 4)
        #expect(slots.map(\.label) == ["01", "02", "03", "04"])
        #expect(slots.allSatisfy { $0.speaker == nil })
    }

    @Test("Partial roster fills the first slots, remaining are placeholders")
    func partial() {
        let slots = Speaker.slots(
            [item(id: "a", order: 0), item(id: "b", order: 1)],
            minSlotCount: 4
        )
        #expect(slots.count == 4)
        #expect(slots[0].speaker?.id == "a")
        #expect(slots[1].speaker?.id == "b")
        #expect(slots[2].speaker == nil)
        #expect(slots[3].speaker == nil)
    }

    @Test("Roster larger than the minimum doesn't truncate — show every assigned speaker")
    func overflow() {
        let slots = Speaker.slots(
            [item(id: "a", order: 0), item(id: "b", order: 1),
             item(id: "c", order: 2), item(id: "d", order: 3),
             item(id: "e", order: 4)],
            minSlotCount: 4
        )
        #expect(slots.count == 5)
        #expect(slots.map(\.label) == ["01", "02", "03", "04", "05"])
    }

    @Test("Slot identity stays stable: empty slots key by index, filled by speaker id")
    func identity() {
        let slots = Speaker.slots(
            [item(id: "real-id-xyz", order: 0)],
            minSlotCount: 3
        )
        #expect(slots[0].id == "real-id-xyz")
        // Empty slots' ids must differ from each other so SwiftUI's diff is stable.
        #expect(slots[1].id != slots[2].id)
    }
}
