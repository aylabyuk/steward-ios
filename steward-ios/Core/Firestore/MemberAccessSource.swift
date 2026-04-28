import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Adapter for the web-mirrored allowlist query
/// `collectionGroup("members") where email == X and active == true`.
/// Encodes each match's parent path as `"\(wardId)/\(uid)"` in
/// `CollectionSnap.Doc.id` so the pure `WardAccessClient` can resolve
/// `WardAccess` without depending on Firestore.
struct MemberAccessSource: SnapshotSource, Sendable {
    typealias Snap = CollectionSnap

    let email: String

    func snapshots() -> AsyncStream<Result<CollectionSnap, Error>> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Result<CollectionSnap, Error>.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let registration = Firestore.firestore()
            .collectionGroup("members")
            .whereField("email", isEqualTo: email)
            .whereField("active", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    continuation.yield(.failure(error))
                    return
                }
                guard let snapshot else { return }
                let docs: [CollectionSnap.Doc] = snapshot.documents.compactMap { qds in
                    // Path is `wards/{wardId}/members/{uid}`.
                    let parts = qds.reference.path.split(separator: "/")
                    guard parts.count >= 4,
                          parts[0] == "wards",
                          parts[2] == "members"
                    else {
                        return nil
                    }
                    let wardId = String(parts[1])
                    let uid = String(parts[3])
                    let cleaned = sanitizeMemberDoc(qds.data())
                    guard let dict = cleaned as? [String: Any],
                          let data = try? JSONSerialization.data(withJSONObject: dict)
                    else {
                        return nil
                    }
                    return .init(id: "\(wardId)/\(uid)", data: data)
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

/// Same shape as `FirestoreCollectionSource.sanitizeForJSON` — drops
/// non-JSON-serialisable values (`Timestamp`, `GeoPoint`, etc.) before
/// re-encoding so the `MemberBody` decoder downstream sees only what
/// `JSONDecoder` accepts.
private func sanitizeMemberDoc(_ value: Any) -> Any? {
    switch value {
    case let dict as [String: Any]:
        var result: [String: Any] = [:]
        result.reserveCapacity(dict.count)
        for (key, raw) in dict {
            if let cleaned = sanitizeMemberDoc(raw) {
                result[key] = cleaned
            }
        }
        return result
    case let array as [Any]:
        return array.compactMap(sanitizeMemberDoc)
    case let timestamp as Timestamp:
        return ISO8601DateFormatter().string(from: timestamp.dateValue())
    case is NSNull: return NSNull()
    case let bool as Bool: return bool
    case let number as NSNumber: return number
    case let string as String: return string
    default: return nil
    }
}
#endif
