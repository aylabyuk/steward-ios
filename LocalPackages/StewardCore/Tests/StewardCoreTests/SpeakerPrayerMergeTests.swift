import Foundation
import Testing
@testable import StewardCore

/// Drives the live-update behaviour the chat banner needs for prayers.
/// Prayer participant docs at `prayers/{role}` carry only status fields
/// — name / email / phone / invitationId live on the inline meeting
/// assignment, not on the subcollection doc — so decoding the
/// participant doc into a full `Speaker` would fail on the missing
/// non-optional `name`. The merge keeps the snapshot's identity fields
/// and folds in the live status fields so the banner reflects the
/// current Firestore state without losing display name.
@Suite("Speaker.merging(prayerParticipantJSON:) — prayer subscription decode")
struct SpeakerPrayerMergeTests {

    private let snapshot = Speaker(
        name: "Yoyo",
        email: "yoyo@example.com",
        phone: "+1 555 0100",
        topic: nil,
        status: "invited",
        role: nil,
        order: nil,
        statusSource: nil,
        statusSetBy: nil,
        statusSetAt: nil,
        invitationId: "inv_abc123"
    )

    @Test("Live status fields override the snapshot's stale status")
    func livestatusOverridesSnapshot() throws {
        let json = """
        {
          "role": "opening",
          "status": "confirmed",
          "statusSource": "manual",
          "statusSetBy": "G2Bcy1N7aLAAkZd94WYqDwJ9cYwV",
          "statusSetAt": "2026-04-28T22:51:20Z"
        }
        """.data(using: .utf8)!

        let merged = try snapshot.merging(prayerParticipantJSON: json)

        #expect(merged.status == "confirmed")
        #expect(merged.statusSource == "manual")
        #expect(merged.statusSetBy == "G2Bcy1N7aLAAkZd94WYqDwJ9cYwV")
        #expect(merged.statusSetAt == "2026-04-28T22:51:20Z")
    }

    @Test("Snapshot's identity fields are preserved (name / email / phone / invitationId)")
    func identityFieldsPreserved() throws {
        let json = """
        {
          "role": "opening",
          "status": "confirmed",
          "statusSource": "manual"
        }
        """.data(using: .utf8)!

        let merged = try snapshot.merging(prayerParticipantJSON: json)

        #expect(merged.name == "Yoyo")
        #expect(merged.email == "yoyo@example.com")
        #expect(merged.phone == "+1 555 0100")
        #expect(merged.invitationId == "inv_abc123")
    }

    @Test("Missing status fields decode as nil — no crash on a fresh participant doc")
    func partialPayloadDecodes() throws {
        let json = """
        {
          "role": "opening"
        }
        """.data(using: .utf8)!

        let merged = try snapshot.merging(prayerParticipantJSON: json)

        #expect(merged.name == "Yoyo")
        #expect(merged.status == nil)
        #expect(merged.statusSource == nil)
    }

    @Test("Participant doc with no `name` field still decodes — that was the original bug")
    func nameAbsenceDoesNotFailDecode() throws {
        // The exact shape the user observed in the Firestore emulator:
        // role/status/statusSetAt/statusSetBy/statusSource/updatedAt,
        // no `name`. Decoding this into a vanilla `Speaker` would have
        // failed; the merge variant must succeed and pull `name` from
        // the snapshot.
        let json = """
        {
          "role": "opening",
          "status": "confirmed",
          "statusSetAt": "2026-04-28T22:51:20Z",
          "statusSetBy": "G2Bcy1N7aLAAkZd94WYqDwJ9cYwV",
          "statusSource": "manual",
          "updatedAt": "2026-04-28T22:51:20Z"
        }
        """.data(using: .utf8)!

        let merged = try snapshot.merging(prayerParticipantJSON: json)

        #expect(merged.name == "Yoyo")
        #expect(merged.status == "confirmed")
    }
}
