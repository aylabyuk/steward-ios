import Foundation

/// In-memory `SnapshotSource` for tests. Constructed with the modern
/// `AsyncStream.makeStream(of:)` factory so the continuation isn't trapped
/// inside a closure. The continuation is exposed so tests can push fake
/// snapshots and trigger errors at deterministic moments.
public final class MockSnapshotSource<Snap: Sendable>: SnapshotSource, Sendable {
    public typealias Snap = Snap

    private let stream: AsyncStream<Result<Snap, Error>>
    public let continuation: AsyncStream<Result<Snap, Error>>.Continuation

    public init() {
        let made = AsyncStream.makeStream(of: Result<Snap, Error>.self)
        self.stream = made.stream
        self.continuation = made.continuation
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
