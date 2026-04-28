import Testing
@testable import StewardCore

/// Mirrors the web's INVITATION_STATUSES enum at
/// src/lib/types/meeting.ts:13-19. Speakers and prayers share the same
/// four-state lifecycle, so one type covers both surfaces.

@Suite("InvitationStatus — round-trips and tone mapping")
struct InvitationStatusTests {

    @Test(
        "Each canonical raw string decodes to its case",
        arguments: [
            (raw: "planned",   expected: InvitationStatus.planned),
            (raw: "invited",   expected: InvitationStatus.invited),
            (raw: "confirmed", expected: InvitationStatus.confirmed),
            (raw: "declined",  expected: InvitationStatus.declined),
        ]
    )
    func canonicalDecode(raw: String, expected: InvitationStatus) {
        #expect(InvitationStatus(rawString: raw) == expected)
    }

    @Test("Each case round-trips back to its raw string")
    func roundTrip() {
        for status in InvitationStatus.allCases {
            #expect(InvitationStatus(rawString: status.rawValue) == status)
        }
    }

    @Test("Unknown raw strings decode to nil so a future server status doesn't crash the parse")
    func unknownIsNil() {
        #expect(InvitationStatus(rawString: nil) == nil)
        #expect(InvitationStatus(rawString: "") == nil)
        #expect(InvitationStatus(rawString: "future-status") == nil)
    }

    @Test("Decoding is case-insensitive — backend may emit canonical or upper-case")
    func caseInsensitive() {
        #expect(InvitationStatus(rawString: "PLANNED") == .planned)
        #expect(InvitationStatus(rawString: "Confirmed") == .confirmed)
    }

    @Test(
        "Each status maps to the StatusBadge tone the bishopric reads",
        arguments: [
            (status: InvitationStatus.planned,   expected: StatusBadge.Tone.neutral),
            (status: InvitationStatus.invited,   expected: StatusBadge.Tone.pending),
            (status: InvitationStatus.confirmed, expected: StatusBadge.Tone.success),
            (status: InvitationStatus.declined,  expected: StatusBadge.Tone.destructive),
        ]
    )
    func tone(status: InvitationStatus, expected: StatusBadge.Tone) {
        #expect(status.tone == expected)
    }
}
