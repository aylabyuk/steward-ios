import Foundation

/// Codable mirror of the web's `speakerLetterTemplateSchema` and
/// `prayerLetterTemplateSchema` at
/// `src/lib/types/template.ts:85-107`. The web is mid-migration from
/// Markdown → Lexical and dual-writes both fields; iOS v1 reads only
/// `bodyMarkdown` + `footerMarkdown`. The Lexical `editorStateJson`
/// field is decoded for forward-compat but unused in the preview.
public struct LetterTemplate: Codable, Sendable, Equatable {
    public let bodyMarkdown: String
    public let footerMarkdown: String
    public let editorStateJson: String?

    public init(bodyMarkdown: String, footerMarkdown: String = "", editorStateJson: String? = nil) {
        self.bodyMarkdown = bodyMarkdown
        self.footerMarkdown = footerMarkdown
        self.editorStateJson = editorStateJson
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bodyMarkdown = try container.decodeIfPresent(String.self, forKey: .bodyMarkdown) ?? ""
        self.footerMarkdown = try container.decodeIfPresent(String.self, forKey: .footerMarkdown) ?? ""
        self.editorStateJson = try container.decodeIfPresent(String.self, forKey: .editorStateJson)
    }

    private enum CodingKeys: String, CodingKey {
        case bodyMarkdown
        case footerMarkdown
        case editorStateJson
    }
}
