import Foundation
import StewardCore

/// Hashable wrapper the schedule view passes via `path.append(...)` to
/// push the `ConversationView`. Carries the snapshot the chat view
/// uses for first paint, plus the row coordinates needed to start a
/// live `DocSubscription<Speaker>` for cross-device sync.
struct ChatPresentation: Identifiable, Hashable {
    let kind: SlotKind
    /// ISO `YYYY-MM-DD` — the meeting doc id the speaker / prayer
    /// row belongs to. Threaded through so the chat view can build
    /// the live subscription path without re-fetching.
    let meetingDate: String
    /// For speakers, the auto-generated speaker doc id. For prayers,
    /// the role string (`"opening"` / `"benediction"`) — same back-
    /// compat carve-out the web's `speakerRef.speakerId` uses.
    let speakerId: String
    /// First-paint snapshot of the row from the schedule's collection
    /// subscription. The chat view's own subscription supersedes it
    /// once it loads.
    let speaker: Speaker

    var id: String { "\(kind.rawValue)-\(meetingDate)-\(speakerId)" }

    /// Synthesize a `Speaker` snapshot from a prayer meeting
    /// `Assignment`. Loses fields the prayer flow doesn't carry
    /// (topic, role, order, statusSource, etc.) which is fine — the
    /// chat sheet only reads name + status to render the banner.
    static func forPrayer(
        meetingDate: String,
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
        return ChatPresentation(kind: kind, meetingDate: meetingDate, speakerId: role, speaker: speaker)
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
