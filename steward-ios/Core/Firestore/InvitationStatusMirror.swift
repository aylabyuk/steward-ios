import Foundation
import StewardCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore
@preconcurrency import TwilioConversationsClient

/// Mirror status changes onto the invitation doc + post a system
/// notice into the Twilio Conversation. Mirrors the web's
/// `noteBishopStatusChange` at
/// `src/features/invitations/utils/statusChangeNotice.ts:36-65`.
///
/// Two side effects, both best-effort, both exposed as separate
/// methods so the caller can choose which one runs (the chat view
/// holds the live `TCHConversation`; the schedule view doesn't).
enum InvitationStatusMirror {

    /// Update `speakerInvitations/{id}.currentSpeakerStatus` so the
    /// speaker landing page surfaces up-to-date status without
    /// needing read access to the meeting-scoped speaker doc.
    /// Best-effort — failures are logged and swallowed since this
    /// only affects the speaker's bottom-banner copy.
    static func mirrorCurrentSpeakerStatus(
        wardId: String,
        invitationId: String,
        status: InvitationStatus
    ) async {
        let ref = Firestore.firestore()
            .collection("wards").document(wardId)
            .collection("speakerInvitations").document(invitationId)
        do {
            try await ref.setData(
                ["currentSpeakerStatus": status.rawValue],
                merge: true
            )
        } catch {
            print("[InvitationStatusMirror] currentSpeakerStatus mirror failed: \(error)")
        }
    }

    /// Body copy mirrors the web at
    /// `statusChangeNotice.ts:14-18`. The meeting date is substituted
    /// in place of "this Sunday" so an old thread reads unambiguously.
    /// Confirm copy branches on `kind` so prayer chats don't read as
    /// speaker-flavoured ("thank you for speaking" → "thank you for
    /// offering the prayer"); decline copy is kind-agnostic.
    /// Returns the empty string for `planned`/`invited` — the web
    /// caller short-circuits before posting in those cases.
    static func bodyFor(
        status: InvitationStatus,
        kind: SlotKind,
        meetingDate: String
    ) -> String {
        let when = LetterInterpolator.fullSundayDate(meetingDate)
        switch status {
        case .confirmed: return "Assignment confirmed — thank you for \(kind.assigneeAction) on \(when)."
        case .declined:  return "Assignment updated to declined. Thank you for letting us know."
        case .planned, .invited: return ""
        }
    }

    /// Post the centred system notice into the Twilio Conversation.
    /// Only confirmed/declined transitions get a chat line — the web
    /// short-circuits the same way. Best-effort: a failure leaves the
    /// banner status correct but the chat without a notice line.
    static func postStatusChangeMessage(
        conversation: TCHConversation,
        status: InvitationStatus,
        kind: SlotKind,
        meetingDate: String
    ) async {
        guard status == .confirmed || status == .declined else { return }
        let body = bodyFor(status: status, kind: kind, meetingDate: meetingDate)
        let attributes: [String: Any] = [
            "kind": "status-change",
            "status": status.rawValue,
        ]
        do {
            try await sendStructuredMessage(
                in: conversation,
                body: body,
                attributes: attributes
            )
        } catch {
            print("[InvitationStatusMirror] status-change chat message failed: \(error)")
        }
    }

    /// Post the tombstone system notice that replaces a deleted bubble.
    /// iOS deviation from the web — the web silently removes; iOS
    /// leaves an audit line so the speaker sees who removed what and
    /// when. Best-effort: a failure leaves the message gone but the
    /// thread without the tombstone (which is the same as web).
    static func postMessageDeletedNotice(
        conversation: TCHConversation,
        removedBy displayName: String?,
        on date: Date = Date()
    ) async {
        let body = DeletedMessageNotice.body(removedBy: displayName, on: date)
        let attributes: [String: Any] = [
            "kind": "message-deleted",
        ]
        do {
            try await sendStructuredMessage(
                in: conversation,
                body: body,
                attributes: attributes
            )
        } catch {
            print("[InvitationStatusMirror] message-deleted tombstone failed: \(error)")
        }
    }

    private static func sendStructuredMessage(
        in conversation: TCHConversation,
        body: String,
        attributes: [String: Any]
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Twilio's `withAttributes(_:)` returns Optional under
            // Swift 6's strict bridge — only nil when the attributes
            // can't be serialized. Our payload is a known-safe dict,
            // but fall back to body-only if it does return nil so
            // the notice still posts.
            let options: TCHMessageOptions = TCHMessageOptions().withBody(body)
            let final: TCHMessageOptions
            if let attrs = TCHJsonAttributes(dictionary: attributes),
               let withAttrs = options.withAttributes(attrs) {
                final = withAttrs
            } else {
                final = options
            }
            conversation.sendMessage(with: final) { result, _ in
                if result.isSuccessful {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "InvitationStatusMirror",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: result.error?.localizedDescription ?? "send failed"]
                    ))
                }
            }
        }
    }
}

#endif
