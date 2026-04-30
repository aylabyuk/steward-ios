import Foundation

/// Classifies a requested speaker-status change into the friction level
/// the menu should apply: silently apply, mutate immediately, or pop a
/// confirmation dialog first.
///
/// Mirrors the gating in the web's `SpeakerStatusPills.tsx`
/// `requestChange(...)` helper. The terminal states (confirmed/declined)
/// always need friction to leave; planned/invited transitions all need
/// friction except the one frictionless rollback "invited → planned"
/// (no real commitment to erase).
public enum SpeakerStatusTransition {

    public enum Decision: Sendable, Equatable {
        /// The bishop tapped the status they're already on. The menu
        /// should leave a checkmark and not write anything.
        case noOp
        /// Apply the change immediately. The only path that lands here
        /// today is invited → planned.
        case frictionless
        /// Show the `StatusConfirmCopy` alert before applying.
        case requiresConfirmation
    }

    public static func classify(
        current: InvitationStatus,
        next: InvitationStatus
    ) -> Decision {
        if next == current { return .noOp }
        let leavingTerminal = current == .confirmed || current == .declined
        if !leavingTerminal && next == .planned { return .frictionless }
        return .requiresConfirmation
    }
}
