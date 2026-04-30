import Foundation
import Testing
@testable import StewardCore

/// Encoding parity with the web's `callSendSpeakerInvitation` payload at
/// src/features/templates/utils/sendSpeakerInvitation.ts:91-110. The Cloud
/// Function validates the input via Zod (`speakerInvitationRequestSchema`),
/// where `optional()` accepts undefined / missing — never `null`. So
/// `encodeIfPresent`-style omission of nil optionals is load-bearing,
/// not cosmetic; sending `speakerTopic: null` would fail the parse.

@Suite("SendSpeakerInvitationRequest — what we hand to the callable")
struct SendSpeakerInvitationRequestEncodingTests {

    private func baseSpeakerDraft() -> InvitationDraft {
        InvitationDraft(
            kind: .speaker,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Sister Daisylene Oliquino",
            email: "daisy@example.com",
            phone: "+14165550123",
            topic: "On gratitude",
            role: .member
        )
    }

    @Test("Speaker payload includes the kind discriminator and the speaker doc id")
    func speakerCarriesKind() throws {
        let req = SendSpeakerInvitationRequest.fresh(
            draft: baseSpeakerDraft(),
            speakerId: "spk_42",
            channels: [],
            bodyMarkdown: "Dear sister",
            footerMarkdown: "— bishopric",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )

        let dict = try req.encodeAsDictionary()
        #expect(dict["mode"] as? String == "fresh")
        #expect(dict["kind"] as? String == "speaker")
        #expect(dict["wardId"] as? String == "stv1")
        #expect(dict["speakerId"] as? String == "spk_42")
        #expect(dict["meetingDate"] as? String == "2026-05-17")
        #expect(dict["speakerName"] as? String == "Sister Daisylene Oliquino")
        #expect(dict["speakerTopic"] as? String == "On gratitude")
        #expect(dict["bishopReplyToEmail"] as? String == "bishop@e2e.local")
        #expect(dict["expiresAtMillis"] as? Int64 == 1_747_440_000_000)
        #expect(dict["assignedDate"] as? String == "Sunday, May 17, 2026")
        #expect(dict["sentOn"] as? String == "April 28, 2026")
        #expect(dict["bodyMarkdown"] as? String == "Dear sister")
        #expect(dict["footerMarkdown"] as? String == "— bishopric")
        #expect(dict["channels"] as? [String] == [])
        #expect(dict["speakerEmail"] as? String == "daisy@example.com")
        #expect(dict["speakerPhone"] as? String == "+14165550123")
        #expect(dict["prayerRole"] == nil, "speakers don't carry a prayerRole")
    }

    @Test("Prayer payload sets kind=prayer and prayerRole — speakerId holds the role string")
    func prayerCarriesRole() throws {
        let draft = InvitationDraft(
            kind: .openingPrayer,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Brother Jensen"
        )
        let req = SendSpeakerInvitationRequest.fresh(
            draft: draft,
            speakerId: "opening",
            channels: [],
            bodyMarkdown: "Dear brother",
            footerMarkdown: "— bishopric",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )

        let dict = try req.encodeAsDictionary()
        #expect(dict["kind"] as? String == "prayer")
        #expect(dict["prayerRole"] as? String == "opening")
        #expect(dict["speakerId"] as? String == "opening", "the role string lives in speakerId per the back-compat carve-out in speakerInvitation.ts:80-88")
    }

    @Test("Benediction prayer maps to prayerRole = benediction")
    func benedictionCarriesRole() throws {
        let draft = InvitationDraft(
            kind: .benediction,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Brother Jensen"
        )
        let req = SendSpeakerInvitationRequest.fresh(
            draft: draft,
            speakerId: "benediction",
            channels: [],
            bodyMarkdown: "—",
            footerMarkdown: "—",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )

        let dict = try req.encodeAsDictionary()
        #expect(dict["prayerRole"] as? String == "benediction")
    }

    @Test("Empty optional fields are omitted, not serialized as null — Zod rejects null for .optional()")
    func nilOptionalsOmitted() throws {
        let draft = InvitationDraft(
            kind: .speaker,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Sister Bensen",
            email: nil,
            phone: nil,
            topic: nil,
            role: .member
        )
        let req = SendSpeakerInvitationRequest.fresh(
            draft: draft,
            speakerId: "spk_99",
            channels: [],
            bodyMarkdown: "—",
            footerMarkdown: "—",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )

        let dict = try req.encodeAsDictionary()
        #expect(dict["speakerTopic"] == nil)
        #expect(dict["speakerEmail"] == nil)
        #expect(dict["speakerPhone"] == nil)
        #expect(dict["editorStateJson"] == nil)
        #expect(dict["useTestingNumber"] == nil)
        #expect(dict["prayerRole"] == nil)
    }

    @Test("Whitespace-only contact fields are treated as no-channel — match the web's .trim() guard")
    func whitespaceContactFieldsOmitted() throws {
        let draft = InvitationDraft(
            kind: .speaker,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Sister Bensen",
            email: "   ",
            phone: "  ",
            topic: "  ",
            role: .member
        )
        let req = SendSpeakerInvitationRequest.fresh(
            draft: draft,
            speakerId: "spk_99",
            channels: [],
            bodyMarkdown: "—",
            footerMarkdown: "—",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )

        let dict = try req.encodeAsDictionary()
        #expect(dict["speakerEmail"] == nil)
        #expect(dict["speakerPhone"] == nil)
        #expect(dict["speakerTopic"] == nil)
    }

    @Test("Channels round-trip — empty array means 'invitation record only' (out-of-band delivery)")
    func channelsRoundTrip() throws {
        let req = SendSpeakerInvitationRequest.fresh(
            draft: baseSpeakerDraft(),
            speakerId: "spk_1",
            channels: ["sms"],
            bodyMarkdown: "—",
            footerMarkdown: "—",
            sentOn: "April 28, 2026",
            assignedDate: "Sunday, May 17, 2026",
            bishopReplyToEmail: "bishop@e2e.local",
            expiresAtMillis: 1_747_440_000_000
        )
        let dict = try req.encodeAsDictionary()
        #expect(dict["channels"] as? [String] == ["sms"])
    }
}

@Suite("SendSpeakerInvitationRequest.computeExpiresAt — Monday-after-Sunday at local 00:00")
struct ComputeExpiresAtTests {

    /// Mirrors `src/features/templates/utils/sendSpeakerInvitation.ts:120-127` —
    /// civil-date math in the sender's local time, +1 day from the meeting Sunday,
    /// 00:00:00.000. Phase 1 callers use this so the field validates server-side
    /// without a per-call override.
    @Test("Sunday May 17 2026 → Monday May 18 2026 at local midnight")
    func sundayBumpsToNextDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "America/Toronto")!
        let millis = SendSpeakerInvitationRequest.computeExpiresAt(
            meetingDate: "2026-05-17",
            calendar: calendar,
            timeZone: timeZone
        )
        var expected = DateComponents()
        expected.year = 2026
        expected.month = 5
        expected.day = 18
        expected.hour = 0
        expected.minute = 0
        expected.timeZone = timeZone
        let expectedDate = calendar.date(from: expected)!
        #expect(millis == Int64(expectedDate.timeIntervalSince1970 * 1000))
    }

    @Test("Malformed date string falls back to 'now-ish' rather than throwing")
    func malformedDateFallsBack() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let millis = SendSpeakerInvitationRequest.computeExpiresAt(meetingDate: "not-a-date")
        // Within 5 seconds of "now" — the function should fall back to current time.
        #expect(abs(millis - now) < 5_000)
    }
}
