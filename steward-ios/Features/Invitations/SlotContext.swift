import Foundation
import StewardCore

/// Navigation value pushed onto the schedule's NavigationStack when the
/// bishopric taps an empty slot's `Assign…` pill. Carries every input
/// `AssignSlotFormView` needs to construct an `InvitationDraft` —
/// scoping ids (wardId / meetingDate), the kind of slot, and the
/// ambient labels (wardName / inviterName) we'd otherwise have to
/// re-derive in the destination.
struct SlotContext: Hashable, Sendable {
    let wardId: String
    let meetingDate: String
    let kind: SlotKind
    let wardName: String
    let inviterName: String
}
