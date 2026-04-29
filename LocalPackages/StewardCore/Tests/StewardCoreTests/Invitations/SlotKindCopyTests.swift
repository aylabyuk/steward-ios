import Foundation
import Testing
@testable import StewardCore

/// Drives the kind-aware copy used in the chat banner and status
/// notices. Speakers see "speaker" / "speaking"; opening + closing
/// prayer-givers see "prayer giver" / "offering the prayer". iOS
/// deviation from the web — the web's chat banner reads as
/// speaker-flavoured even for prayer slots.
@Suite("SlotKind copy properties — assignee noun + action verb")
struct SlotKindCopyTests {

    @Test(
        "Assignee noun matches the slot's role",
        arguments: [
            (kind: SlotKind.speaker,        noun: "speaker"),
            (kind: SlotKind.openingPrayer,  noun: "prayer giver"),
            (kind: SlotKind.benediction,    noun: "prayer giver"),
        ]
    )
    func assigneeNoun(kind: SlotKind, noun: String) {
        #expect(kind.assigneeNoun == noun)
    }

    @Test(
        "Action verb describes what the assignee will do at the meeting",
        arguments: [
            (kind: SlotKind.speaker,        verb: "speaking"),
            (kind: SlotKind.openingPrayer,  verb: "offering the prayer"),
            (kind: SlotKind.benediction,    verb: "offering the prayer"),
        ]
    )
    func assigneeAction(kind: SlotKind, verb: String) {
        #expect(kind.assigneeAction == verb)
    }
}
