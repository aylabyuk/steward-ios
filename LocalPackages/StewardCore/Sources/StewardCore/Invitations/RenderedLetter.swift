import Foundation

/// The fully-interpolated letter ready to render in the preview and to
/// hand to `UIActivityViewController` as the share payload. Produced by
/// `InvitationPreviewView` after the ward template loads + the draft's
/// variable map is applied.
public struct RenderedLetter: Sendable, Equatable {
    public let bodyMarkdown: String
    public let footerMarkdown: String
    /// The share-sheet payload. A naive Markdown → plain conversion
    /// (strip `*`, `_`, leading `#`s) so iOS's Mail / Messages /
    /// WhatsApp activities receive readable text. Lossy by design —
    /// the web's print path is the canonical typeset output; this is
    /// the "good enough" mobile fallback.
    public let plainText: String

    public init(bodyMarkdown: String, footerMarkdown: String) {
        self.bodyMarkdown = bodyMarkdown
        self.footerMarkdown = footerMarkdown
        let combined = footerMarkdown.isEmpty
            ? bodyMarkdown
            : "\(bodyMarkdown)\n\n\(footerMarkdown)"
        self.plainText = RenderedLetter.stripMarkdown(combined)
    }

    /// Pulls the obvious Markdown markers out so the share sheet sees
    /// flat text. Doesn't try to be a full Markdown parser — the
    /// preview screen renders the real `AttributedString(markdown:)`
    /// and the web is the canonical typeset output.
    static func stripMarkdown(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.count)
        var iterator = raw.unicodeScalars.makeIterator()
        var atLineStart = true
        while let scalar = iterator.next() {
            switch scalar {
            case "*", "_":
                continue
            case "#" where atLineStart:
                // Drop the leading run of `#`s plus the following space.
                while let next = iterator.next() {
                    if next == "#" { continue }
                    if next == " " { break }
                    result.unicodeScalars.append(next)
                    break
                }
            case "\n":
                result.unicodeScalars.append(scalar)
                atLineStart = true
                continue
            default:
                result.unicodeScalars.append(scalar)
            }
            atLineStart = false
        }
        return result
    }
}
