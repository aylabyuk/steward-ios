import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Adapter that bridges `Firestore.firestore().collection(...).addSnapshotListener`
/// into the pure `SnapshotSource<CollectionSnap>` protocol that lives in
/// `StewardCore`. Each call to `snapshots()` registers a fresh listener;
/// the listener is removed when the returned stream's continuation
/// terminates (consumer stops iterating or the wrapper deinits).
struct FirestoreCollectionSource: SnapshotSource, Sendable {
    typealias Snap = CollectionSnap

    let path: String

    func snapshots() -> AsyncStream<Result<CollectionSnap, Error>> {
        // Use the modern factory rather than the closure-based AsyncStream
        // initializer so the continuation isn't trapped inside a closure
        // we'd otherwise have to fish out via a shared property.
        let (stream, continuation) = AsyncStream.makeStream(
            of: Result<CollectionSnap, Error>.self,
            // Bound the buffer in case Firestore fires faster than the UI
            // can render. We only ever care about the latest snapshot.
            bufferingPolicy: .bufferingNewest(1)
        )
        let registration = Firestore.firestore()
            .collection(path)
            .addSnapshotListener { snapshot, error in
                if let error {
                    continuation.yield(.failure(error))
                    return
                }
                guard let snapshot else { return }
                let docs: [CollectionSnap.Doc] = snapshot.documents.compactMap { qds in
                    let cleaned = sanitizeForJSON(qds.data())
                    guard
                        let dict = cleaned as? [String: Any],
                        let data = try? JSONSerialization.data(withJSONObject: dict)
                    else {
                        return nil
                    }
                    return .init(id: qds.documentID, data: data)
                }
                continuation.yield(.success(
                    .init(docs: docs, fromCache: snapshot.metadata.isFromCache)
                ))
            }
        continuation.onTermination = { _ in
            registration.remove()
        }
        return stream
    }
}

/// Walks a Firestore-shaped value and returns a JSON-serialisable equivalent.
/// `Timestamp` -> ISO 8601 string; `GeoPoint`/`DocumentReference` are dropped
/// (Phase 0 doesn't need them); arrays and dictionaries recurse; primitives
/// pass through. Returns nil to indicate "drop this value entirely".
private func sanitizeForJSON(_ value: Any) -> Any? {
    switch value {
    case let dict as [String: Any]:
        var result: [String: Any] = [:]
        result.reserveCapacity(dict.count)
        for (key, raw) in dict {
            if let cleaned = sanitizeForJSON(raw) {
                result[key] = cleaned
            }
        }
        return result
    case let array as [Any]:
        return array.compactMap(sanitizeForJSON)
    case let timestamp as Timestamp:
        return ISO8601DateFormatter().string(from: timestamp.dateValue())
    case is NSNull:
        return NSNull()
    case let bool as Bool:
        return bool
    case let number as NSNumber:
        return number
    case let string as String:
        return string
    default:
        return nil
    }
}
#endif
