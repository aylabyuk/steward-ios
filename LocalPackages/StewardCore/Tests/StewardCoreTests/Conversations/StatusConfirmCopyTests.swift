import Foundation
import Testing
@testable import StewardCore

/// Pure port of the web's `computeConfirmCopy` at
/// `src/features/schedule/utils/speakerStatusConfirmCopy.ts`. The
/// confirm dialog is the friction layer that prevents misclicks from
/// erasing real commitments — text drift here changes the dialog
/// the bishopric reads, so every branch is pinned.

@Suite("StatusConfirmCopy — what the speaker-status-pill confirm dialog reads")
struct StatusConfirmCopyTests {

    @Test("Forward to invited has the base 'Mark as Invited?' title")
    func forwardInvited() {
        let copy = StatusConfirmCopy.compute(
            current: "planned",
            next: "invited",
            currentStatusSource: nil,
            currentStatusSetBy: nil,
            membersByUid: [:],
            currentUserUid: nil
        )
        #expect(copy.title == "Mark as Invited?")
        #expect(copy.confirmLabel == "Mark as Invited")
        #expect(copy.danger == false)
    }

    @Test("Forward to confirmed has the 'Mark as Confirmed?' title")
    func forwardConfirmed() {
        let copy = StatusConfirmCopy.compute(
            current: "invited",
            next: "confirmed",
            currentStatusSource: nil,
            currentStatusSetBy: nil,
            membersByUid: [:],
            currentUserUid: nil
        )
        #expect(copy.title == "Mark as Confirmed?")
        #expect(copy.danger == false)
    }

    @Test("Forward to declined raises the danger flag — bordeaux confirm button")
    func forwardDeclinedIsDangerous() {
        let copy = StatusConfirmCopy.compute(
            current: "invited",
            next: "declined",
            currentStatusSource: nil,
            currentStatusSetBy: nil,
            membersByUid: [:],
            currentUserUid: nil
        )
        #expect(copy.title == "Mark as Declined?")
        #expect(copy.danger)
    }

    @Test("Rolling back from confirmed → planned uses the heavy-friction copy")
    func rollbackConfirmedToPlanned() {
        let copy = StatusConfirmCopy.compute(
            current: "confirmed",
            next: "planned",
            currentStatusSource: "manual",
            currentStatusSetBy: "uid:bishop",
            membersByUid: ["uid:bishop": "Bishop Smith"],
            currentUserUid: "uid:bishop"
        )
        #expect(copy.title.lowercased().contains("clear"))
        // "You" prefix when the same user is rolling back their own action
        #expect(copy.body.contains("You"))
        #expect(copy.danger)
    }

    @Test("Rolling back from declined → invited uses the 'undo decline' copy")
    func rollbackDeclinedToInvited() {
        let copy = StatusConfirmCopy.compute(
            current: "declined",
            next: "invited",
            currentStatusSource: nil,
            currentStatusSetBy: nil,
            membersByUid: [:],
            currentUserUid: nil
        )
        #expect(copy.title.lowercased().contains("undo"))
        #expect(copy.confirmLabel.lowercased().contains("undo"))
        #expect(copy.danger)
    }

    @Test("Speaker-response provenance prefixes the body with 'The speaker set this status by replying'")
    func provenancePrefixSpeakerResponse() {
        let copy = StatusConfirmCopy.compute(
            current: "invited",
            next: "declined",
            currentStatusSource: "speaker-response",
            currentStatusSetBy: "speaker:1",
            membersByUid: [:],
            currentUserUid: "uid:bishop"
        )
        #expect(copy.body.contains("The speaker set this status"))
    }

    @Test("Another bishop's prior status surfaces their name in the prefix")
    func provenancePrefixOtherBishop() {
        let copy = StatusConfirmCopy.compute(
            current: "invited",
            next: "declined",
            currentStatusSource: "manual",
            currentStatusSetBy: "uid:colleague",
            membersByUid: ["uid:colleague": "Brother Jensen"],
            currentUserUid: "uid:bishop"
        )
        #expect(copy.body.contains("Brother Jensen"))
    }

    @Test("Same user's own prior status doesn't get a redundant prefix")
    func sameUserNoSelfPrefix() {
        let copy = StatusConfirmCopy.compute(
            current: "invited",
            next: "declined",
            currentStatusSource: "manual",
            currentStatusSetBy: "uid:bishop",
            membersByUid: ["uid:bishop": "Bishop Smith"],
            currentUserUid: "uid:bishop"
        )
        #expect(copy.body.contains("Bishop Smith") == false)
    }
}
