import Foundation

/// Decides whether a bishop's proposed edit should fire a Twilio
/// `updateBody` write. Centralizes the trim / blank / unchanged
/// rules so the SwiftUI sheet stays dumb and the rules are
/// testable without a host view.
public enum EditMessageIntent {

    /// Returns the trimmed proposal when it represents a real edit
    /// (non-empty after trim AND differs from the current body),
    /// otherwise nil. The caller treats nil as a no-op dismissal —
    /// no Twilio write, no error, just close the sheet.
    public static func normalize(currentBody: String, proposedBody: String) -> String? {
        let trimmed = proposedBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard trimmed != currentBody.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return trimmed
    }
}
