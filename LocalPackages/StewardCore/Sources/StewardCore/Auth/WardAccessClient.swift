import Foundation
import Observation

/// Drives `WardAccess` from a `SnapshotSource<CollectionSnap>` whose
/// underlying query is the web app's allowlist lookup:
/// `collectionGroup("members") where email == X and active == true`.
///
/// The source's adapter encodes the parent ward + uid into each
/// `CollectionSnap.Doc.id` as `"\(wardId)/\(uid)"` so the resolution
/// logic stays a pure transform from a snapshot to a `WardAccess`.
@Observable
@MainActor
public final class WardAccessClient {
    public private(set) var state: WardAccess = .checking

    private var task: Task<Void, Never>?

    public init(source: (any SnapshotSource<CollectionSnap>)?) {
        guard let source else {
            // Email not yet known (sign-in still in flight). Stay in
            // `.checking` until a future call site re-creates the client
            // with a real source.
            return
        }
        let stream = source.snapshots()
        task = Task { [weak self] in
            for await result in stream {
                guard let self else { return }
                self.handle(result)
            }
        }
    }

    isolated deinit {
        task?.cancel()
    }

    private func handle(_ result: Result<CollectionSnap, Error>) {
        switch result {
        case .success(let snap):
            let members = snap.docs.compactMap(Self.decode)
            state = Self.deriveState(from: members)
        case .failure:
            // Mirror the web's `useWardAccess.ts:75-79`: source error is
            // treated as no-access rather than retried. The user can
            // sign out + sign back in if it was transient.
            state = .none
        }
    }

    /// Exposed for unit tests / future composability.
    static func decode(_ doc: CollectionSnap.Doc) -> MemberAccess? {
        let parts = doc.id.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].isEmpty == false, parts[1].isEmpty == false else {
            return nil
        }
        let body = (try? JSONDecoder().decode(MemberBody.self, from: doc.data))
            ?? MemberBody(role: nil, displayName: nil)
        return MemberAccess(
            wardId: parts[0],
            uid: parts[1],
            role: body.role,
            displayName: body.displayName
        )
    }

    static func deriveState(from members: [MemberAccess]) -> WardAccess {
        switch members.count {
        case 0: .none
        case 1: .single(members[0])
        default: .multiple(members)
        }
    }

    private struct MemberBody: Decodable {
        let role: String?
        let displayName: String?
    }
}
