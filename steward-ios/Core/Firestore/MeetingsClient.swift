import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Firestore write helpers for the `wards/{wardId}/meetings/{date}` doc.
/// Mirrors the web's `updateMeetingField` / `ensureMeetingDoc` pair, but
/// minus the approval-hashing and history-event tracking. Those layers
/// only matter once the meeting moves past `draft` status; until they
/// land on iOS we keep the writes minimal.
///
/// Deviation from the web: no `nonMeetingSundays` override yet — the
/// type fallback comes from `Meeting.fallbackType(forDate:)` (date-based,
/// first-Sunday-of-month → fast). Wire the ward-settings subscription
/// in to honour custom overrides when that lands.
enum MeetingsClient {

    /// Writes `meetingType` on the meeting doc. Uses `merge: true` so
    /// the doc is created with the field set if it doesn't exist yet,
    /// or patched in place if it does. The bishopric is the only writer
    /// (Firestore rules enforce), so a last-write-wins update is safe
    /// for this draft-state field.
    static func setMeetingType(wardId: String, date: String, type: String) async throws {
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(date)
        try await ref.setData([
            "meetingType": type,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }
}
#endif
