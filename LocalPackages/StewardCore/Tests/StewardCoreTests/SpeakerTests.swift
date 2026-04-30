import Foundation
import Testing
@testable import StewardCore

/// User-facing tests for what the speaker rows show on each meeting card.

@Suite("Speaker decoding — what `meetings/{date}/speakers/{id}` translates into")
struct SpeakerDecodingTests {

    @Test("A fully-populated speaker doc decodes every visible field")
    func happyPath() throws {
        let json = """
        {
            "name": "Brother Tes Ting",
            "email": "tes@example.com",
            "phone": "555-0123",
            "topic": "Faith",
            "status": "confirmed",
            "role": "Member",
            "order": 0
        }
        """.data(using: .utf8)!
        let speaker = try JSONDecoder().decode(Speaker.self, from: json)
        #expect(speaker.name == "Brother Tes Ting")
        #expect(speaker.status == "confirmed")
        #expect(speaker.role == "Member")
        #expect(speaker.order == 0)
        #expect(speaker.topic == "Faith")
    }

    @Test("Status provenance fields decode when the web (or iOS post-callable) writes them")
    func provenanceFields() throws {
        // The web stamps `statusSource`, `statusSetBy`, and `statusSetAt`
        // every time a status changes (manual via pills, or
        // speaker-response via Apply). The chat-banner pill confirm
        // dialog reads these to surface "X set the current status —
        // override with care" copy. `statusSetAt` is the timestamp
        // the chat banner's status-provenance line formats.
        let json = """
        {
            "name": "Brother Tes Ting",
            "status": "confirmed",
            "statusSource": "speaker-response",
            "statusSetBy": "uid:abc123",
            "statusSetAt": "2026-04-28T15:00:00Z",
            "invitationId": "inv_xyz"
        }
        """.data(using: .utf8)!
        let speaker = try JSONDecoder().decode(Speaker.self, from: json)
        #expect(speaker.statusSource == "speaker-response")
        #expect(speaker.statusSetBy == "uid:abc123")
        #expect(speaker.statusSetAt == "2026-04-28T15:00:00Z")
        #expect(speaker.invitationId == "inv_xyz")
    }

    @Test("Provenance fields are optional — pre-rollout docs still decode")
    func provenanceOptional() throws {
        let json = #"{"name": "Brother Tes Ting", "status": "invited"}"#.data(using: .utf8)!
        let speaker = try JSONDecoder().decode(Speaker.self, from: json)
        #expect(speaker.statusSource == nil)
        #expect(speaker.statusSetBy == nil)
        #expect(speaker.statusSetAt == nil)
        #expect(speaker.invitationId == nil)
    }

    @Test("Optional fields stay optional — a minimal doc still decodes")
    func minimal() throws {
        let json = #"{"name": "Sister Davis"}"#.data(using: .utf8)!
        let speaker = try JSONDecoder().decode(Speaker.self, from: json)
        #expect(speaker.name == "Sister Davis")
        #expect(speaker.status == nil)
        #expect(speaker.order == nil)
    }

    @Test("Unknown extra fields don't break decoding")
    func extras() throws {
        let json = #"{"name": "X", "letterOverride": {"bodyMarkdown": "..."}, "future": true}"#
            .data(using: .utf8)!
        let speaker = try JSONDecoder().decode(Speaker.self, from: json)
        #expect(speaker.name == "X")
    }
}

@Suite("Speaker slot ordering — what order the user reads the rows in")
struct SpeakerOrderingTests {

    private func item(id: String, order: Int? = nil, name: String = "X") -> CollectionItem<Speaker> {
        CollectionItem(id: id, data: Speaker(name: name, status: nil, role: nil, order: order))
    }

    @Test("Speakers sort ascending by `order` so 0 reads as slot 01")
    func basicOrder() {
        let sorted = Speaker.sorted([
            item(id: "c", order: 2),
            item(id: "a", order: 0),
            item(id: "b", order: 1),
        ])
        #expect(sorted.map(\.id) == ["a", "b", "c"])
    }

    @Test("Speakers without an `order` value sort to the end deterministically by id")
    func missingOrderGoesLast() {
        let sorted = Speaker.sorted([
            item(id: "c", order: nil),
            item(id: "a", order: 0),
            item(id: "b", order: nil),
        ])
        #expect(sorted.map(\.id) == ["a", "b", "c"])
    }
}

@Suite("Speaker slot label — what number prefixes the row")
struct SpeakerSlotLabelTests {

    @Test(
        "Index zero-pads to two digits so '01' aligns with '12'",
        arguments: [
            (index: 0, expected: "01"),
            (index: 1, expected: "02"),
            (index: 9, expected: "10"),
            (index: 11, expected: "12"),
        ]
    )
    func zeroPad(index: Int, expected: String) {
        #expect(Speaker.slotLabel(forIndex: index) == expected)
    }
}

@Suite("Speaker.displayTopic — what the schedule row shows under the speaker name")
struct SpeakerDisplayTopicTests {

    private func speaker(topic: String?) -> Speaker {
        Speaker(name: "Sarah", topic: topic, status: nil, role: nil, order: nil)
    }

    @Test("A real topic is returned verbatim")
    func realTopic() {
        #expect(speaker(topic: "Faith").displayTopic == "Faith")
    }

    @Test("Nil topic falls back to 'Topic of Choice' so the row never reads empty")
    func nilTopic() {
        #expect(speaker(topic: nil).displayTopic == "Topic of Choice")
    }

    @Test("Empty topic falls back to the same placeholder")
    func emptyTopic() {
        #expect(speaker(topic: "").displayTopic == "Topic of Choice")
    }

    @Test("Whitespace-only topic falls back too — bishop typed and erased")
    func whitespaceTopic() {
        #expect(speaker(topic: "   ").displayTopic == "Topic of Choice")
        #expect(speaker(topic: "\t\n").displayTopic == "Topic of Choice")
    }

    @Test("Topic with leading/trailing whitespace is trimmed before display")
    func trimsRealTopic() {
        #expect(speaker(topic: "  Faith  ").displayTopic == "Faith")
    }
}

@Suite("Speaker.canAddMore — when the schedule card surfaces an Add row")
struct SpeakerCanAddMoreTests {

    @Test(
        "Floor=2, ceiling=4: Add row only shows when the typical roster is met but ceiling isn't",
        arguments: [
            (assignedCount: 0, expected: false), // empty meeting — placeholders are the affordance
            (assignedCount: 1, expected: false), // one filled, one placeholder still visible
            (assignedCount: 2, expected: true),  // typical roster filled — surface the 3rd
            (assignedCount: 3, expected: true),  // still room for one more
            (assignedCount: 4, expected: false), // ceiling reached
            (assignedCount: 5, expected: false), // defensive: never happens, mustn't crash
        ]
    )
    func defaultBounds(assignedCount: Int, expected: Bool) {
        #expect(
            Speaker.canAddMore(assignedCount: assignedCount, floor: 2, ceiling: 4) == expected
        )
    }

    @Test("A floor of 0 still gates on the ceiling — caller controls the rule")
    func zeroFloor() {
        #expect(Speaker.canAddMore(assignedCount: 0, floor: 0, ceiling: 4))
        #expect(Speaker.canAddMore(assignedCount: 4, floor: 0, ceiling: 4) == false)
    }

    @Test("Floor equal to ceiling never opens the Add row — defensive against misconfig")
    func degenerateBounds() {
        #expect(Speaker.canAddMore(assignedCount: 2, floor: 2, ceiling: 2) == false)
        #expect(Speaker.canAddMore(assignedCount: 0, floor: 4, ceiling: 4) == false)
    }
}

@Suite("Speaker.hasConfirmed — when the schedule card locks the Sunday-Type menu")
struct SpeakerHasConfirmedTests {

    private func item(id: String, status: String?) -> CollectionItem<Speaker> {
        CollectionItem(id: id, data: Speaker(name: "X", status: status))
    }

    @Test("Empty roster reads as no-confirmed — menu stays unlocked")
    func empty() {
        #expect(Speaker.hasConfirmed([]) == false)
    }

    @Test("All-planned / invited roster keeps the menu unlocked")
    func plannedAndInvited() {
        let items = [
            item(id: "a", status: "planned"),
            item(id: "b", status: "invited"),
        ]
        #expect(Speaker.hasConfirmed(items) == false)
    }

    @Test("A single confirmed speaker locks the menu")
    func oneConfirmed() {
        let items = [
            item(id: "a", status: "planned"),
            item(id: "b", status: "confirmed"),
        ]
        #expect(Speaker.hasConfirmed(items))
    }

    @Test("Status field is matched as the literal lowercase 'confirmed' the web writes")
    func caseSensitive() {
        // The web writes lowercase "confirmed". Stay strict so an unknown
        // future status (e.g. "Confirmed") doesn't accidentally lock the
        // menu — the bishop should keep agency on truly unknown states.
        #expect(Speaker.hasConfirmed([item(id: "a", status: "Confirmed")]) == false)
    }

    @Test("Nil-status speakers don't lock — partial drafts and legacy docs stay editable")
    func nilStatus() {
        #expect(Speaker.hasConfirmed([item(id: "a", status: nil)]) == false)
    }

    @Test("Declined speakers don't lock — the bishop must move them on first")
    func declined() {
        #expect(Speaker.hasConfirmed([item(id: "a", status: "declined")]) == false)
    }
}

@Suite("Speaker.firestoreData — what the bishop's new-speaker write puts on the wire")
struct SpeakerFirestoreDataTests {

    private func draft(
        topic: String? = "Faith",
        email: String? = nil,
        phone: String? = nil
    ) -> InvitationDraft {
        InvitationDraft(
            kind: .speaker,
            wardId: "stv1",
            meetingDate: "2026-05-17",
            wardName: "Eglinton Ward",
            inviterName: "Bishop Smith",
            name: "Sarah Bensen",
            email: email,
            phone: phone,
            topic: topic,
            role: .member
        )
    }

    @Test("Required fields land on the dict")
    func requiredFields() {
        let dict = Speaker.firestoreData(for: draft(), status: .planned, order: 2)
        #expect(dict["name"] as? String == "Sarah Bensen")
        #expect(dict["topic"] as? String == "Faith")
        #expect(dict["role"] as? String == "Member") // web raw value
        #expect(dict["status"] as? String == "planned")
        #expect(dict["order"] as? Int == 2)
    }

    @Test("Empty / nil email and phone are omitted so the doc stays tidy")
    func optionalsOmitted() {
        let dict = Speaker.firestoreData(for: draft(email: nil, phone: nil), status: .planned)
        #expect(dict["email"] == nil)
        #expect(dict["phone"] == nil)
        let dict2 = Speaker.firestoreData(for: draft(email: "", phone: ""), status: .planned)
        #expect(dict2["email"] == nil)
        #expect(dict2["phone"] == nil)
    }

    @Test("Provided email and phone surface verbatim")
    func optionalsPresent() {
        let dict = Speaker.firestoreData(
            for: draft(email: "sarah@example.com", phone: "555-0123"),
            status: .invited
        )
        #expect(dict["email"] as? String == "sarah@example.com")
        #expect(dict["phone"] as? String == "555-0123")
        #expect(dict["status"] as? String == "invited")
    }

    @Test("An empty topic falls back to nil rather than writing a blank string")
    func emptyTopicOmitted() {
        let dict = Speaker.firestoreData(for: draft(topic: ""), status: .planned)
        #expect(dict["topic"] == nil)
    }
}
