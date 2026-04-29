import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Speaker / prayer-giver removal. Mirrors the web's `deleteSpeaker`
/// at `src/features/speakers/utils/speakerActions.ts:126-146` for the
/// speaker case; for prayers, clears the inline meeting field that
/// the schedule reads (`meeting.openingPrayer` / `meeting.benediction`).
///
/// History events + meeting-patch propagation are deliberately out of
/// scope for v1 — same call site as `SpeakerStatusClient`. Twilio
/// conversations are NOT deleted: orphaning the conversation is fine,
/// the speaker's chat history stays in the record.
enum SpeakerDeletionClient {

    static func deleteSpeaker(
        wardId: String,
        meetingDate: String,
        speakerId: String
    ) async throws {
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
            .collection("speakers").document(speakerId)
        try await ref.delete()
    }

    /// Clear the inline prayer assignment by deleting the field entirely.
    /// `FieldValue.delete()` removes the key from the doc rather than
    /// writing nil — keeps the meeting doc tidy and matches what an
    /// empty slot looks like on first read.
    static func deletePrayerAssignment(
        wardId: String,
        meetingDate: String,
        kind: SlotKind
    ) async throws {
        guard let field = kind.meetingField else { return }
        let meetingRef = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
        let participantRef = meetingRef
            .collection("prayers").document(kind.prayerRoleString ?? "")

        let batch = Firestore.firestore().batch()
        batch.updateData(
            [
                field: FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            forDocument: meetingRef
        )
        // Also delete the subcollection participant doc if it exists.
        // `delete()` on a non-existent doc is a no-op, so this is
        // safe regardless of whether the prayer was ever invited via
        // the callable (which is what creates the subcollection doc).
        if kind.prayerRoleString != nil {
            batch.deleteDocument(participantRef)
        }
        try await batch.commit()
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

    var meetingField: String? {
        switch self {
        case .speaker:        return nil
        case .openingPrayer:  return "openingPrayer"
        case .benediction:    return "benediction"
        }
    }
}

#endif
