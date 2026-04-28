import Foundation
import Observation

/// Observable wrapper around a `SnapshotSource<DocSnap>` that mirrors
/// `useDocSnapshot` from `src/hooks/_sub.ts`. Two behaviours that bit the web
/// app and must be preserved here:
///   1. Stay `loading == true` until the source is non-nil (i.e. the path's
///      segments are all populated). Without this, callers read the
///      pre-subscription frame as "loaded with no data" and seed defaults.
///   2. Skip the synthetic `fromCache && !exists` first fire that Firestore
///      emits before the network response arrives. (Implemented in a
///      subsequent slice; the current source contract is `DocSnap`.)
@Observable
@MainActor
public final class DocSubscription<T: Decodable & Sendable> {
    public private(set) var data: T?
    public private(set) var loading: Bool = true
    public private(set) var error: Error?

    nonisolated(unsafe) private var task: Task<Void, Never>?

    public init(
        source: (any SnapshotSource<DocSnap>)?,
        decoder: @escaping @Sendable (Data) throws -> T
    ) {
        guard let source else {
            // Path segments not ready yet — stay loading until a future
            // subscription is started. Callers re-create the wrapper when
            // segments resolve.
            return
        }
        let stream = source.snapshots()
        task = Task { [weak self] in
            for await result in stream {
                guard let self else { return }
                self.handle(result, decoder: decoder)
            }
        }
    }

    deinit {
        task?.cancel()
    }

    private func handle(
        _ result: Result<DocSnap, Error>,
        decoder: @Sendable (Data) throws -> T
    ) {
        switch result {
        case .success(let snap):
            // Mirrors src/hooks/_sub.ts:62-72 — Firestore can fire onSnapshot
            // up to twice on first subscribe: once with fromCache=true (local
            // cache, often empty on first visit) and again with fromCache=false
            // once the network responds. The cache-miss fire reports
            // exists=false even when the server has the document, which races
            // the authoritative result. Skip those entirely so callers see one
            // clean resolution.
            if snap.fromCache && snap.exists == false {
                return
            }
            if snap.exists == false {
                self.data = nil
                self.loading = false
                self.error = nil
                return
            }
            guard let bytes = snap.data else {
                self.data = nil
                self.loading = false
                self.error = nil
                return
            }
            do {
                self.data = try decoder(bytes)
                self.error = nil
            } catch {
                self.data = nil
                self.error = error
            }
            self.loading = false
        case .failure(let error):
            self.data = nil
            self.loading = false
            self.error = error
        }
    }
}
