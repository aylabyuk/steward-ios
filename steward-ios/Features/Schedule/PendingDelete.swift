import Foundation
import StewardCore

/// Hashable wrapper the schedule view passes to `.sheet(item:)` when a
/// non-planned row is swiped + tapped Remove. Carries the row context
/// the confirmation sheet needs to render its body, plus enough
/// metadata to perform the actual Firestore delete on confirm.
///
/// Planned rows skip this entirely — `MeetingCardSection` deletes
/// straight through without putting a `PendingDelete` on the wire.
struct PendingDelete: Identifiable, Hashable {
    let kind: SlotKind
    /// `meetingDate` is the parent meeting's ISO date — needed to
    /// build the Firestore path on confirm.
    let meetingDate: String
    /// Speaker doc id, or the role string (`"opening"` /
    /// `"benediction"`) for prayers.
    let speakerId: String
    let speakerName: String
    let status: InvitationStatus

    var id: String { "\(kind.rawValue)-\(meetingDate)-\(speakerId)" }
}
