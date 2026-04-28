import Foundation
import Observation
import OSLog

/// Decoded item with the parent collection's document ID attached.
public struct CollectionItem<T: Sendable>: Sendable, Identifiable {
    public let id: String
    public let data: T
    public init(id: String, data: T) {
        self.id = id
        self.data = data
    }
}

extension CollectionItem: Equatable where T: Equatable {}

/// Observable wrapper around a `SnapshotSource<CollectionSnap>` that mirrors
/// `useCollectionSnapshot` from `src/hooks/_sub.ts`. Two important behaviours:
///   1. Stay `loading == true` until the source is non-nil (path-readiness).
///   2. Skip malformed docs rather than blanking the list — one bad document
///      shouldn't make recovery harder for the whole feature
///      (`src/hooks/_sub.ts:127-132`).
@Observable
@MainActor
public final class CollectionSubscription<T: Decodable & Sendable> {
    public private(set) var items: [CollectionItem<T>] = []
    public private(set) var loading: Bool = true
    public private(set) var error: Error?

    nonisolated(unsafe) private var task: Task<Void, Never>?

    public init(
        source: (any SnapshotSource<CollectionSnap>)?,
        decoder: @escaping @Sendable (Data) throws -> T,
        path: String? = nil
    ) {
        guard let source else { return }
        let stream = source.snapshots()
        task = Task { [weak self] in
            for await result in stream {
                guard let self else { return }
                self.handle(result, decoder: decoder, path: path)
            }
        }
    }

    deinit {
        task?.cancel()
    }

    private func handle(
        _ result: Result<CollectionSnap, Error>,
        decoder: @Sendable (Data) throws -> T,
        path: String?
    ) {
        switch result {
        case .success(let snap):
            var decoded: [CollectionItem<T>] = []
            decoded.reserveCapacity(snap.docs.count)
            for doc in snap.docs {
                do {
                    decoded.append(.init(id: doc.id, data: try decoder(doc.data)))
                } catch {
                    Self.logger.error(
                        "Schema parse failed at \(path ?? "<unknown>", privacy: .public)/\(doc.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            self.items = decoded
            self.loading = false
            self.error = nil
        case .failure(let error):
            self.items = []
            self.loading = false
            self.error = error
        }
    }

    private static var logger: Logger {
        Logger(subsystem: "ca.thevincistudios.stewardcore", category: "CollectionSubscription")
    }
}
