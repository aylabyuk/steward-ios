import Foundation

/// A snapshot of a single Firestore document — abstracted so the subscription
/// wrapper in `StewardCore` can be exercised without depending on Firebase.
public struct DocSnap: Sendable, Equatable {
    public let exists: Bool
    public let fromCache: Bool
    public let data: Data?

    public init(exists: Bool, fromCache: Bool, data: Data?) {
        self.exists = exists
        self.fromCache = fromCache
        self.data = data
    }
}

/// A snapshot of a Firestore collection. `docs` is `(id, raw JSON)` pairs;
/// the consumer owns decoding so one bad document can be skipped without
/// blanking the list (mirrors `src/hooks/_sub.ts:127-132` on the web).
public struct CollectionSnap: Sendable {
    public let docs: [Doc]
    public let fromCache: Bool

    public struct Doc: Sendable, Identifiable {
        public let id: String
        public let data: Data
        public init(id: String, data: Data) {
            self.id = id
            self.data = data
        }
    }

    public init(docs: [Doc], fromCache: Bool) {
        self.docs = docs
        self.fromCache = fromCache
    }
}

/// Abstract source of snapshots. Each call to `snapshots()` returns a new
/// `AsyncStream` and registers a fresh underlying listener; cancelling the
/// stream's iterator (or letting it deinit) removes the listener.
///
/// In the app target a Firestore-backed adapter implements this against
/// `Firestore.firestore().document(...).addSnapshotListener(...)`. Tests use
/// `MockSnapshotSource` to push synthetic snapshots through the wrapper.
public protocol SnapshotSource<Snap>: Sendable {
    associatedtype Snap: Sendable
    func snapshots() -> AsyncStream<Result<Snap, Error>>
}
