import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Helper for subscribing to a ward's letter template doc. The two
/// supported paths mirror the web's storage:
///   - `wards/{wardId}/templates/speakerLetter`
///   - `wards/{wardId}/templates/prayerLetter`
///
/// Returns a fresh `DocSubscription<LetterTemplate>` each call so the
/// caller (the preview view) owns it as `@State` and gets its own
/// listener. The subscription stays in `loading == true` until the
/// emulator / production server responds.
enum LetterTemplateSource {

    static func subscription(wardId: String, kind: SlotKind) -> DocSubscription<LetterTemplate> {
        let path = "wards/\(wardId)/templates/\(kind.templateDocId)"
        let source = FirestoreDocSource(path: path)
        return DocSubscription<LetterTemplate>(
            source: source,
            decoder: { try JSONDecoder().decode(LetterTemplate.self, from: $0) }
        )
    }
}

private extension SlotKind {
    /// The wards/{id}/templates/{docId} key the web uses. Both prayer
    /// kinds share `prayerLetter`; speakers have `speakerLetter`.
    var templateDocId: String {
        switch self {
        case .speaker:        "speakerLetter"
        case .openingPrayer,
             .benediction:    "prayerLetter"
        }
    }
}
#endif
