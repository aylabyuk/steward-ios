import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Status writes for the chat-sheet status pills (Phase 2). Mirrors
/// the web's `updateSpeaker` (`src/features/speakers/utils/speakerActions.ts:80-124`)
/// and `upsertPrayerParticipant`
/// (`src/features/prayers/utils/prayerActions.ts:49-110`). Stamps
/// provenance fields (`statusSource`, `statusSetBy`, `statusSetAt`)
/// so the next bishop reading the chat sheet sees who set the status.
///
/// History events + meeting-patch mirroring are intentionally out of
/// scope for v1 — those are append-only audit writes the iOS app
/// can grow into when needed without changing this entry point.
enum SpeakerStatusClient {

    /// Update a speaker's status from the chat-sheet pills. Stamps
    /// `statusSource: "manual"` always (the speaker-response code
    /// path lives server-side in `applyResponseToSpeaker` and isn't
    /// reachable from iOS yet).
    static func updateSpeakerStatus(
        wardId: String,
        meetingDate: String,
        speakerId: String,
        status: InvitationStatus,
        setBy uid: String
    ) async throws {
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
            .collection("speakers").document(speakerId)
        try await ref.setData(
            [
                "status": status.rawValue,
                "statusSource": "manual",
                "statusSetBy": uid,
                "statusSetAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            merge: true
        )
    }

    /// Update a prayer participant's status from the chat-sheet pills.
    /// Writes to the prayer-participant subcollection AND mirrors the
    /// inline meeting assignment row (`meeting.openingPrayer` /
    /// `meeting.benediction`) so the schedule's inline read stays in
    /// sync — same write topology as the web's
    /// `upsertPrayerParticipant`.
    static func updatePrayerStatus(
        wardId: String,
        meetingDate: String,
        kind: SlotKind,
        status: InvitationStatus,
        setBy uid: String
    ) async throws {
        guard let role = kind.prayerRoleString, let meetingField = kind.meetingField else {
            return
        }
        let participantRef = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
            .collection("prayers").document(role)
        let meetingRef = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)

        let batch = Firestore.firestore().batch()
        batch.setData(
            [
                "role": role,
                "status": status.rawValue,
                "statusSource": "manual",
                "statusSetBy": uid,
                "statusSetAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            forDocument: participantRef,
            merge: true
        )
        batch.setData(
            [
                meetingField: [
                    "status": status.rawValue,
                    "confirmed": status == .confirmed,
                ],
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            forDocument: meetingRef,
            merge: true
        )
        try await batch.commit()
    }
}

private extension SlotKind {
    /// `"opening"` / `"benediction"` — the prayer participant doc id.
    /// Nil for speakers (which use a different write path).
    var prayerRoleString: String? {
        switch self {
        case .speaker:        return nil
        case .openingPrayer:  return "opening"
        case .benediction:    return "benediction"
        }
    }

    /// Inline field on the meeting doc the web mirrors prayer status
    /// onto. Nil for speakers (they live in a subcollection).
    var meetingField: String? {
        switch self {
        case .speaker:        return nil
        case .openingPrayer:  return "openingPrayer"
        case .benediction:    return "benediction"
        }
    }
}

#endif
