import Foundation
import Testing
@testable import StewardCore

/// User-facing behaviour tests for the ward header presentation:
/// what the bishopric reads in the dark top bar of every screen.

@Suite("Ward decoding — what the wards/{wardId} doc translates into")
struct WardDecodingTests {

    @Test("A ward doc with a name decodes into a Ward with that name")
    func happyPath() throws {
        let json = #"{"name": "Eglinton Ward"}"#.data(using: .utf8)!
        let ward = try JSONDecoder().decode(Ward.self, from: json)
        #expect(ward.name == "Eglinton Ward")
    }

    @Test("A ward doc without a name decodes into a Ward whose name is nil")
    func missingName() throws {
        let json = "{}".data(using: .utf8)!
        let ward = try JSONDecoder().decode(Ward.self, from: json)
        #expect(ward.name == nil)
    }

    @Test("Extra unknown fields don't break decoding")
    func extraFields() throws {
        let json = #"{"name": "Eglinton Ward", "createdAt": "2025-01-01T00:00:00Z", "stake": "stv"}"#
            .data(using: .utf8)!
        let ward = try JSONDecoder().decode(Ward.self, from: json)
        #expect(ward.name == "Eglinton Ward")
    }
}

@Suite("Ward header title — what the user reads in the top bar")
struct WardHeaderTitleTests {

    @Test("When the ward doc is loaded with a name, the bar shows that name")
    func withName() {
        let title = Ward.displayTitle(ward: Ward(name: "Eglinton Ward"), wardId: "stv1")
        #expect(title == "Eglinton Ward")
    }

    @Test("While the ward doc is still loading, the bar falls back to the wardId")
    func loading() {
        let title = Ward.displayTitle(ward: nil, wardId: "stv1")
        #expect(title == "stv1")
    }

    @Test("If the ward doc has no name set, the bar falls back to the wardId")
    func emptyName() {
        let title = Ward.displayTitle(ward: Ward(name: nil), wardId: "stv1")
        #expect(title == "stv1")
    }

    @Test("A whitespace-only name is treated like no name and falls back to wardId")
    func whitespaceOnly() {
        let title = Ward.displayTitle(ward: Ward(name: "   "), wardId: "stv1")
        #expect(title == "stv1")
    }
}
