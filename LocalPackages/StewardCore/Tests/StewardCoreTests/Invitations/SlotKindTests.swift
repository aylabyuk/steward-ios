import Testing
@testable import StewardCore

@Suite("SlotKind — what label the empty-slot button shows")
struct SlotKindTests {

    @Test(
        "Each kind exposes the actionable button copy the bishopric taps",
        arguments: [
            (kind: SlotKind.speaker,        expected: "Assign Speaker"),
            (kind: SlotKind.openingPrayer,  expected: "Assign Opening Prayer"),
            (kind: SlotKind.benediction,    expected: "Assign Closing Prayer"),
        ]
    )
    func assignButtonLabel(kind: SlotKind, expected: String) {
        #expect(kind.assignButtonLabel == expected)
    }

    @Test("Form title matches the button copy so the pushed page reads consistently")
    func formTitle() {
        #expect(SlotKind.speaker.formTitle == "Assign Speaker")
        #expect(SlotKind.openingPrayer.formTitle == "Assign Opening Prayer")
        #expect(SlotKind.benediction.formTitle == "Assign Closing Prayer")
    }

    @Test("Prayer kinds expose the {{prayerType}} variable for the letter template")
    func prayerType() {
        #expect(SlotKind.openingPrayer.prayerType == "Opening Prayer")
        #expect(SlotKind.benediction.prayerType == "Benediction")
    }

    @Test("Speaker slots have no prayer type")
    func speakerHasNoPrayerType() {
        #expect(SlotKind.speaker.prayerType == nil)
    }

    @Test("isPrayer flips for prayer kinds")
    func isPrayer() {
        #expect(SlotKind.speaker.isPrayer == false)
        #expect(SlotKind.openingPrayer.isPrayer)
        #expect(SlotKind.benediction.isPrayer)
    }
}
