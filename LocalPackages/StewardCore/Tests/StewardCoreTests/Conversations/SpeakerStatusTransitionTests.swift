import Testing
@testable import StewardCore

/// Drives the user-facing decision the speaker-status menu makes when a
/// bishop picks a status: do we mutate immediately, or pop a confirm
/// dialog first? Mirrors the web's `SpeakerStatusPills.tsx` request
/// flow — terminal states (confirmed/declined) always need friction
/// to leave; "invited → planned" is the one frictionless rollback.
@Suite("SpeakerStatusTransition — frictionless vs. confirmation gating")
struct SpeakerStatusTransitionTests {

    @Test(
        "Tapping the current status is a no-op (the menu surfaces a checkmark, not a write)",
        arguments: InvitationStatus.allCases
    )
    func samePickIsNoOp(status: InvitationStatus) {
        #expect(SpeakerStatusTransition.classify(current: status, next: status) == .noOp)
    }

    @Test("invited → planned is the one frictionless rollback (no real commitment to erase)")
    func invitedToPlannedIsFrictionless() {
        #expect(
            SpeakerStatusTransition.classify(current: .invited, next: .planned)
                == .frictionless
        )
    }

    @Test(
        "Forward moves out of planned all need confirmation",
        arguments: [InvitationStatus.invited, .confirmed, .declined]
    )
    func plannedForwardNeedsConfirmation(next: InvitationStatus) {
        #expect(
            SpeakerStatusTransition.classify(current: .planned, next: next)
                == .requiresConfirmation
        )
    }

    @Test(
        "Forward moves out of invited (other than → planned) need confirmation",
        arguments: [InvitationStatus.confirmed, .declined]
    )
    func invitedForwardNeedsConfirmation(next: InvitationStatus) {
        #expect(
            SpeakerStatusTransition.classify(current: .invited, next: next)
                == .requiresConfirmation
        )
    }

    @Test(
        "Every move out of confirmed (terminal) needs confirmation",
        arguments: [InvitationStatus.planned, .invited, .declined]
    )
    func confirmedRollbackNeedsConfirmation(next: InvitationStatus) {
        #expect(
            SpeakerStatusTransition.classify(current: .confirmed, next: next)
                == .requiresConfirmation
        )
    }

    @Test(
        "Every move out of declined (terminal) needs confirmation",
        arguments: [InvitationStatus.planned, .invited, .confirmed]
    )
    func declinedRollbackNeedsConfirmation(next: InvitationStatus) {
        #expect(
            SpeakerStatusTransition.classify(current: .declined, next: next)
                == .requiresConfirmation
        )
    }
}
