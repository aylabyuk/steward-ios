import Foundation

/// What the four-state RootView routes off of after Auth resolves.
///
/// Mirrors the web's `useWardAccess.ts` `AccessState`:
/// `checking | none | single(member) | multiple(members)`.
public enum WardAccess: Equatable, Sendable {
    /// Initial state, or while a fresh email is being looked up. UI shows a
    /// loading indicator; consumers should not seed defaults from this state.
    case checking
    /// Signed in but no active member doc found — show AccessRequired.
    case none
    /// Exactly one active member doc — auto-resolve `CurrentWard`, route to schedule.
    case single(MemberAccess)
    /// Multiple active member docs — show WardPicker; user chooses one.
    case multiple([MemberAccess])
}

/// A bishopric / clerk member doc returned by the allowlist query
/// (`collectionGroup("members") where email == X and active == true`).
/// `wardId` and `uid` come from the doc's path; `role` and `displayName`
/// come from the doc body. Identifiable by `"\(wardId)/\(uid)"` so the
/// WardPicker can use stable `id`s.
public struct MemberAccess: Equatable, Sendable, Identifiable {
    public let wardId: String
    public let uid: String
    public let role: String?
    public let displayName: String?

    public init(wardId: String, uid: String, role: String?, displayName: String?) {
        self.wardId = wardId
        self.uid = uid
        self.role = role
        self.displayName = displayName
    }

    public var id: String { "\(wardId)/\(uid)" }
}
