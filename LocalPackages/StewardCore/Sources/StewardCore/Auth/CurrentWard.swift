import Foundation
import Observation

/// The wardId the schedule (and every other Firestore-scoped feature) is
/// currently pointed at. Auto-resolves from `WardAccess` for single-ward
/// members; the `WardPicker` UI calls `choose(_:)` for multi-ward members.
///
/// `clear()` is invoked from `AuthClient.signOut()` so the schedule
/// listener tears down in the same tick the auth state flips — mirrors
/// the web's `handleAuthChange` resetting `wardId` on sign-out
/// (`authStore.ts:42-56`), which avoids zombie Firestore listeners
/// holding references through the auth transition.
@Observable
@MainActor
public final class CurrentWard {
    public private(set) var wardId: String?

    public init() {}

    /// Drive the wardId from the latest `WardAccess` state. Indeterminate
    /// states (`.checking`, `.multiple`) leave the existing value alone —
    /// the UI handles those.
    public func resolve(from access: WardAccess) {
        switch access {
        case .single(let member):
            wardId = member.wardId
        case .none:
            wardId = nil
        case .checking, .multiple:
            break
        }
    }

    /// Set explicitly — used by the WardPicker.
    public func choose(_ wardId: String) {
        self.wardId = wardId
    }

    /// Reset — used by sign-out.
    public func clear() {
        wardId = nil
    }
}
