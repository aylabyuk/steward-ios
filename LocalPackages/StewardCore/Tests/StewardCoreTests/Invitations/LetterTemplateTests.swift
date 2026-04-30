import Foundation
import Testing
@testable import StewardCore

/// Codable mirror of the web's speakerLetterTemplateSchema +
/// prayerLetterTemplateSchema (template.ts:85-107). The web is in the
/// middle of a Markdown → Lexical migration and dual-writes both for
/// compatibility — iOS only renders Markdown in v1.

@Suite("LetterTemplate — decoding the ward's stored letter")
struct LetterTemplateDecodingTests {

    @Test("Markdown-only doc decodes (the v1 happy path)")
    func markdownOnly() throws {
        let json = """
        {
            "bodyMarkdown": "Dear {{speakerName}}, ...",
            "footerMarkdown": "Warmly,\\n{{inviterName}}"
        }
        """.data(using: .utf8)!
        let template = try JSONDecoder().decode(LetterTemplate.self, from: json)
        #expect(template.bodyMarkdown == "Dear {{speakerName}}, ...")
        #expect(template.footerMarkdown == "Warmly,\n{{inviterName}}")
        #expect(template.editorStateJson == nil)
    }

    @Test("Lexical editorStateJson decodes when present, but stays unused in v1")
    func lexicalPresent() throws {
        let json = """
        {
            "bodyMarkdown": "fallback body",
            "footerMarkdown": "fallback footer",
            "editorStateJson": "{\\"root\\":{}}"
        }
        """.data(using: .utf8)!
        let template = try JSONDecoder().decode(LetterTemplate.self, from: json)
        #expect(template.editorStateJson == #"{"root":{}}"#)
    }

    @Test("Missing footer decodes to empty string so the preview still renders")
    func missingFooter() throws {
        let json = #"{"bodyMarkdown": "Body only"}"#.data(using: .utf8)!
        let template = try JSONDecoder().decode(LetterTemplate.self, from: json)
        #expect(template.bodyMarkdown == "Body only")
        #expect(template.footerMarkdown == "")
    }

    @Test("Unknown extra fields don't break decoding (web schema is wider)")
    func extras() throws {
        let json = #"""
        {
            "bodyMarkdown": "x",
            "footerMarkdown": "y",
            "pageStyle": {"someKey": "someValue"},
            "updatedAt": null
        }
        """#.data(using: .utf8)!
        let template = try JSONDecoder().decode(LetterTemplate.self, from: json)
        #expect(template.bodyMarkdown == "x")
    }
}
