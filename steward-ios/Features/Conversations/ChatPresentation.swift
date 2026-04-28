import Foundation
import StewardCore

/// Identifiable wrapper the schedule view passes into `.sheet(item:)`
/// to open the `ConversationSheet` for a tapped row. Carries everything
/// the sheet needs without re-fetching from Firestore.
struct ChatPresentation: Identifiable, Hashable {
    let kind: SlotKind
    /// For speakers, the auto-generated speaker doc id. For prayers,
    /// the role string (`"opening"` / `"benediction"`) — same back-
    /// compat carve-out the web's `speakerRef.speakerId` uses.
    let speakerId: String
    let speaker: Speaker

    var id: String { "\(kind.rawValue)-\(speakerId)" }

    /// Synthesize a `Speaker` snapshot from a prayer meeting
    /// `Assignment`. Loses fields the prayer flow doesn't carry
    /// (topic, role, order, statusSource, etc.) which is fine — the
    /// chat sheet only reads name + status to render the banner.
    static func forPrayer(
        kind: SlotKind,
        assignment: Meeting.Assignment
    ) -> ChatPresentation? {
        guard let person = assignment.person,
              let name = person.name, name.isEmpty == false,
              let role = kind.prayerRoleString else { return nil }
        let speaker = Speaker(
            name: name,
            email: person.email,
            phone: person.phone,
            status: assignment.status,
            invitationId: assignment.invitationId
        )
        return ChatPresentation(kind: kind, speakerId: role, speaker: speaker)
    }
}

private extension SlotKind {
    var prayerRoleString: String? {
        switch self {
        case .speaker:        return nil
        case .openingPrayer:  return "opening"
        case .benediction:    return "benediction"
        }
    }
}
