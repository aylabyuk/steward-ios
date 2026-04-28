import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Adapter that bridges `Firestore.firestore().document(...).addSnapshotListener`
/// into the pure `SnapshotSource<DocSnap>` protocol that lives in `StewardCore`.
/// Mirrors `FirestoreCollectionSource` for single-doc subscriptions.
struct FirestoreDocSource: SnapshotSource, Sendable {
    typealias Snap = DocSnap

    let path: String

    func snapshots() -> AsyncStream<Result<DocSnap, Error>> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Result<DocSnap, Error>.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let registration = Firestore.firestore()
            .document(path)
            .addSnapshotListener { snapshot, error in
                if let error {
                    continuation.yield(.failure(error))
                    return
                }
                guard let snapshot else { return }
                let raw = snapshot.data()
                let cleaned = raw.flatMap { sanitizeDocForJSON($0) }
                let bytes = cleaned.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                continuation.yield(.success(.init(
                    exists: snapshot.exists,
                    fromCache: snapshot.metadata.isFromCache,
                    data: bytes
                )))
            }
        continuation.onTermination = { _ in
            registration.remove()
        }
        return stream
    }
}

/// Same Firestore→JSON sanitisation rules as `FirestoreCollectionSource`. Kept
/// duplicated rather than shared to keep each adapter file self-contained;
/// the function is small and the rules don't drift.
private func sanitizeDocForJSON(_ value: [String: Any]) -> [String: Any]? {
    var result: [String: Any] = [:]
    result.reserveCapacity(value.count)
    for (key, raw) in value {
        if let cleaned = sanitizeValue(raw) {
            result[key] = cleaned
        }
    }
    return result
}

private func sanitizeValue(_ value: Any) -> Any? {
    switch value {
    case let dict as [String: Any]:
        return sanitizeDocForJSON(dict)
    case let array as [Any]:
        return array.compactMap(sanitizeValue)
    case let timestamp as Timestamp:
        return ISO8601DateFormatter().string(from: timestamp.dateValue())
    case is NSNull:
        return NSNull()
    case let number as NSNumber:
        // See FirestoreCollectionSource — NSNumber must come before any
        // explicit Bool case to avoid Swift's bridging quirk silently
        // turning integer 0/1 into false/true.
        return number
    case let string as String:
        return string
    default:
        return nil
    }
}
#endif
