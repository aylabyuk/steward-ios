import Foundation
import Testing
@testable import StewardCore

/// What the meeting card's body looks like depends on the kind:
/// regular → numbered speaker slots; fast → testimony stamp; stake or
/// general → "no local program" stamp. Mirrors the web's
/// `kindLabel(type)` + `KIND_MAP` in `src/features/schedule/utils/kindLabel.ts`.

@Suite("Meeting kind — what stamp/description the card body shows")
struct MeetingKindTests {

    @Test(
        "Decoding the raw `meetingType` string into the kind enum",
        arguments: [
            (raw: "regular", expected: MeetingKind.regular),
            (raw: "fast", expected: MeetingKind.fast),
            (raw: "stake", expected: MeetingKind.stake),
            (raw: "general", expected: MeetingKind.general),
        ]
    )
    func decoding(raw: String, expected: MeetingKind) {
        #expect(MeetingKind(rawType: raw) == expected)
    }

    @Test("Unknown / nil raw type defaults to .regular so the card still renders")
    func unknownDefaultsToRegular() {
        #expect(MeetingKind(rawType: nil) == .regular)
        #expect(MeetingKind(rawType: "future-type") == .regular)
        #expect(MeetingKind(rawType: "") == .regular)
    }

    @Test(
        "isSpecial is true for fast/stake/general and false for regular",
        arguments: [
            (kind: MeetingKind.regular, special: false),
            (kind: MeetingKind.fast,    special: true),
            (kind: MeetingKind.stake,   special: true),
            (kind: MeetingKind.general, special: true),
        ]
    )
    func isSpecial(kind: MeetingKind, special: Bool) {
        #expect(kind.isSpecial == special)
    }

    @Test("Stamp label / description copy mirrors the web's KIND_MAP")
    func copy() {
        #expect(MeetingKind.regular.stampLabel == nil)
        #expect(MeetingKind.regular.stampDescription == nil)

        #expect(MeetingKind.fast.stampLabel == "Testimony meeting")
        #expect(MeetingKind.fast.stampDescription == "No assigned speakers — member testimonies.")

        #expect(MeetingKind.stake.stampLabel == "Stake-wide session")
        #expect(MeetingKind.stake.stampDescription == "No local program — stake-wide session.")

        #expect(MeetingKind.general.stampLabel == "General session")
        #expect(MeetingKind.general.stampDescription == "No local program — general session.")
    }

    @Test("Stamp tone matches the type-badge tone so the colour language stays unified")
    func tone() {
        // fast → brass (pending), stake/general → bordeaux (destructive),
        // regular has no stamp so its tone is unused.
        #expect(MeetingKind.fast.stampTone == .pending)
        #expect(MeetingKind.stake.stampTone == .destructive)
        #expect(MeetingKind.general.stampTone == .destructive)
    }

    @Test(
        "hasLocalProgram tells the card whether to render OP/CP rows — stake/general are stake-wide / general-wide so the local ward doesn't pick prayer-givers",
        arguments: [
            (kind: MeetingKind.regular, hasLocal: true),
            (kind: MeetingKind.fast,    hasLocal: true),
            (kind: MeetingKind.stake,   hasLocal: false),
            (kind: MeetingKind.general, hasLocal: false),
        ]
    )
    func localProgram(kind: MeetingKind, hasLocal: Bool) {
        #expect(kind.hasLocalProgram == hasLocal)
    }
}
