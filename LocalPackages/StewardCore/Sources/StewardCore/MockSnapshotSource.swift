import Foundation

/// In-memory `SnapshotSource` for tests. The continuation is exposed so tests
/// can push fake snapshots and trigger errors at deterministic moments.
public final class MockSnapshotSource<Snap: Sendable>: SnapshotSource, @unchecked Sendable {
    public typealias Snap = Snap

    private let stream: AsyncStream<Result<Snap, Error>>
    public let continuation: AsyncStream<Result<Snap, Error>>.Continuation

    public init() {
        var continuation: AsyncStream<Result<Snap, Error>>.Continuation!
        self.stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func snapshots() -> AsyncStream<Result<Snap, Error>> { stream }

    public func emit(_ snap: Snap) {
        continuation.yield(.success(snap))
    }

    public func emit(error: Error) {
        continuation.yield(.failure(error))
    }

    public func finish() {
        continuation.finish()
    }
}
