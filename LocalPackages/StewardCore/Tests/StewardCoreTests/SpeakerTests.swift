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
