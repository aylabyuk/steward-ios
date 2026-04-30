import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Firestore writes for the per-row Assign + Invite flow.
///
/// Two write paths:
///   - **Speakers** land in `wards/{wardId}/meetings/{date}/speakers/{newId}`
///     (auto-generated doc id). The full `Speaker` schema applies; status
///     reflects whether the bishop saved as planned or marked as invited.
///   - **Prayers** patch `meeting.{openingPrayer|benediction}` inline.
///     Inline-status is an iOS-side deviation from the web schema (logged
///     in `docs/web-deviations.md`); the web later reads the
///     `prayers/{role}` subcollection but happily ignores the extra
///     inline field.
///
/// Mirrors `MeetingsClient`'s `setData(merge: true)` style so the doc is
/// created on first write and patched on subsequent writes without
/// blowing away unrelated meeting fields.
enum InvitationsClient {

    /// Writes a new speaker doc to the meeting's `speakers` subcollection.
    /// Returns the auto-generated doc id so the caller can navigate back
    /// to the row it just created (Phase 1 reuse — v1 just pops).
    @discardableResult
    static func writeSpeaker(
        wardId: String,
        meetingDate: String,
        draft: InvitationDraft,
        status: InvitationStatus,
        order: Int? = nil
    ) async throws -> String {
        var data = Speaker.firestoreData(for: draft, status: status, order: order)
        data["createdAt"] = FieldValue.serverTimestamp()
        data["updatedAt"] = FieldValue.serverTimestamp()
        let collection = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
            .collection("speakers")
        let ref = collection.document()
        try await ref.setData(data)
        return ref.documentID
    }

    /// Patches just the `status` field of an existing speaker doc. Used
    /// after the `sendSpeakerInvitation` callable returns: the callable
    /// creates the invitation doc + Twilio Conversation but doesn't flip
    /// the speaker doc's status, so we do it here. Mirrors the web's
    /// post-callable `updateSpeaker(... { status })` at
    /// `usePrepareInvitationActions.ts:117`.
    static func updateSpeakerStatus(
        wardId: String,
        meetingDate: String,
        speakerId: String,
        status: InvitationStatus,
        invitationId: String? = nil
    ) async throws {
        var data: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let invitationId {
            data["invitationId"] = invitationId
        }
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
            .collection("speakers").document(speakerId)
        try await ref.setData(data, merge: true)
    }

    /// Patches the meeting doc's inline prayer Assignment (`openingPrayer`
    /// or `benediction`). Uses `setData(merge: true)` so the meeting doc
    /// is created if missing and untouched fields stay intact. Empty /
    /// nil contact fields are omitted to match the web's lenient Zod
    /// (`z.literal("")` short-circuit) on read.
    static func writePrayerAssignment(
        wardId: String,
        meetingDate: String,
        kind: SlotKind,
        draft: InvitationDraft,
        status: InvitationStatus
    ) async throws {
        guard let field = kind.meetingField else { return }

        var person: [String: Any] = ["name": draft.name]
        if let email = draft.email, email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            person["email"] = email
        }
        if let phone = draft.phone, phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            person["phone"] = phone
        }

        let assignment: [String: Any] = [
            "person": person,
            "confirmed": false,
            "status": status.rawValue,
        ]

        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
        try await ref.setData([
            field: assignment,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    /// Patches just the `status` field of the inline prayer Assignment
    /// after the `sendSpeakerInvitation` callable returns. Same indirection
    /// rationale as `updateSpeakerStatus`: the callable writes the prayer
    /// participant subcollection but iOS reads the inline meeting field
    /// (web-deviations.md "Inline-status field on meeting Assignment"), so
    /// we mirror the status here.
    static func updatePrayerAssignmentStatus(
        wardId: String,
        meetingDate: String,
        kind: SlotKind,
        status: InvitationStatus,
        invitationId: String? = nil
    ) async throws {
        guard let field = kind.meetingField else { return }
        var assignmentPatch: [String: Any] = [
            "status": status.rawValue,
        ]
        if let invitationId {
            assignmentPatch["invitationId"] = invitationId
        }
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("meetings").document(meetingDate)
        try await ref.setData([
            field: assignmentPatch,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }
}

private extension SlotKind {
    /// Which top-level field on the meeting doc this slot writes to.
    /// `nil` for speakers — they live in a subcollection, not inline.
    var meetingField: String? {
        switch self {
        case .speaker:        nil
        case .openingPrayer:  "openingPrayer"
        case .benediction:    "benediction"
        }
    }
}
#endif
