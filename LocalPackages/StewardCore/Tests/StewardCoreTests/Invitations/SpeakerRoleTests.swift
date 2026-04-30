import Testing
@testable import StewardCore

/// Mirrors the web's SPEAKER_ROLES at src/lib/types/meeting.ts:21-23.
/// The web stores the human-readable strings ("Member", "High Council")
/// directly in Firestore, so iOS encodes/decodes the same raw values.

@Suite("SpeakerRole — Firestore raw values + display copy")
struct SpeakerRoleTests {

    @Test(
        "Each web raw value decodes to its case",
        arguments: [
            (raw: "Member",       expected: SpeakerRole.member),
            (raw: "Youth",        expected: SpeakerRole.youth),
            (raw: "High Council", expected: SpeakerRole.highCouncil),
            (raw: "Visiting",     expected: SpeakerRole.visiting),
        ]
    )
    func decode(raw: String, expected: SpeakerRole) {
        #expect(SpeakerRole(rawValue: raw) == expected)
    }

    @Test("Each case round-trips back to the web raw value Firestore expects")
    func roundTrip() {
        #expect(SpeakerRole.member.rawValue == "Member")
        #expect(SpeakerRole.youth.rawValue == "Youth")
        #expect(SpeakerRole.highCouncil.rawValue == "High Council")
        #expect(SpeakerRole.visiting.rawValue == "Visiting")
    }

    @Test("Unknown raw strings decode to nil")
    func unknown() {
        #expect(SpeakerRole(rawValue: "") == nil)
        #expect(SpeakerRole(rawValue: "Bishop") == nil)
    }

    @Test("All cases are exposed for the picker in stable order")
    func allCasesOrder() {
        #expect(SpeakerRole.allCases == [.member, .youth, .highCouncil, .visiting])
    }

    @Test("displayName matches the web raw value (no separate i18n yet)")
    func displayName() {
        for role in SpeakerRole.allCases {
            #expect(role.displayName == role.rawValue)
        }
    }
}
