import Foundation
import Testing
@testable import StewardCore

/// User-facing tests for the ⋯-menu options on each meeting card —
/// what the bishop reads when changing a Sunday's type and what the
/// "Plan / View" action label says depending on whether a meeting doc
/// already exists.

@Suite("Sunday-type menu options — what the bishop picks from")
struct SundayTypeOptionsTests {

    @Test("Four options in canonical order: regular / fast / stake / general")
    func order() {
        let raws = SundayTypeOption.all.map(\.raw)
        #expect(raws == ["regular", "fast", "stake", "general"])
    }

    @Test("Display labels mirror the web's TYPE_LABELS map")
    func labels() {
        let labels = SundayTypeOption.all.map(\.label)
        #expect(labels == [
            "Regular",
            "Fast & Testimony",
            "Stake Conference",
            "General Conference",
        ])
    }

    @Test("Options are Identifiable by raw value so SwiftUI's diff stays stable")
    func identifiable() {
        // Identity is by raw type so the menu's diff key is meaningful.
        #expect(SundayTypeOption.all[0].id == "regular")
        #expect(SundayTypeOption.all[2].id == "stake")
    }
}

@Suite("Plan-action label — what the menu's plan entry reads")
struct PlanActionLabelTests {

    @Test("With no meeting doc, prompts the user to start planning one")
    func noMeeting() {
        #expect(Meeting.planActionLabel(meeting: nil) == "Plan Sacrament Meeting")
    }

    @Test("With an existing meeting doc, links to view the planned meeting")
    func existingMeeting() {
        #expect(
            Meeting.planActionLabel(meeting: Meeting(meetingType: "regular"))
                == "View Meeting"
        )
    }
}
