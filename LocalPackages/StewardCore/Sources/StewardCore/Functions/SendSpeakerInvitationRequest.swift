import Foundation

/// Request payload for the `sendSpeakerInvitation` Cloud Function. Mirrors
/// the web client's payload at `src/features/templates/utils/sendSpeakerInvitation.ts:91-110`
/// and `src/features/prayers/utils/sendPrayerInvitation.ts:60-83`. The
/// server-side validator is in `functions/src/sendSpeakerInvitation.types.ts`.
///
/// Pure value type — no Firebase, no I/O. The app target's `FunctionsClient`
/// converts this to the `[String: Any]` shape `httpsCallable.call(_:)` expects
/// via `encodeAsDictionary()`.
public struct SendSpeakerInvitationRequest: Sendable, Equatable {
    public let mode: String
    public let kind: String
    public let prayerRole: String?
    public let wardId: String
    public let speakerId: String
    public let meetingDate: String
    public let channels: [String]
    public let speakerName: String
    public let speakerTopic: String?
    public let inviterName: String
    public let wardName: String
    public let assignedDate: String
    public let sentOn: String
    public let bodyMarkdown: String
    public let footerMarkdown: String
    public let editorStateJson: String?
    public let speakerEmail: String?
    public let speakerPhone: String?
    public let bishopReplyToEmail: String
    public let expiresAtMillis: Int64
    public let useTestingNumber: Bool?

    /// Build a fresh-mode request from the form-output draft. `speakerId`
    /// is the speaker doc id for `kind == .speaker` and the role string
    /// (`"opening"` | `"benediction"`) for prayer kinds — back-compat with
    /// the web's `speakerRef.speakerId` carve-out (speakerInvitation.ts:80-88).
    /// Whitespace-only contact fields are treated as missing — matches
    /// `.trim()` checks in the web caller.
    public static func fresh(
        draft: InvitationDraft,
        speakerId: String,
        channels: [String],
        bodyMarkdown: String,
        footerMarkdown: String,
        sentOn: String,
        assignedDate: String,
        bishopReplyToEmail: String,
        expiresAtMillis: Int64,
        editorStateJson: String? = nil,
        useTestingNumber: Bool? = nil
    ) -> SendSpeakerInvitationRequest {
        let kind: String = draft.kind.isPrayer ? "prayer" : "speaker"
        let prayerRole: String? = {
            switch draft.kind {
            case .speaker:        return nil
            case .openingPrayer:  return "opening"
            case .benediction:    return "benediction"
            }
        }()
        return SendSpeakerInvitationRequest(
            mode: "fresh",
            kind: kind,
            prayerRole: prayerRole,
            wardId: draft.wardId,
            speakerId: speakerId,
            meetingDate: draft.meetingDate,
            channels: channels,
            speakerName: draft.name,
            speakerTopic: trimToNil(draft.topic),
            inviterName: draft.inviterName,
            wardName: draft.wardName,
            assignedDate: assignedDate,
            sentOn: sentOn,
            bodyMarkdown: bodyMarkdown,
            footerMarkdown: footerMarkdown,
            editorStateJson: editorStateJson,
            speakerEmail: trimToNil(draft.email),
            speakerPhone: trimToNil(draft.phone),
            bishopReplyToEmail: bishopReplyToEmail,
            expiresAtMillis: expiresAtMillis,
            useTestingNumber: useTestingNumber
        )
    }

    /// Encode the request as the dictionary the Firebase Functions SDK
    /// hands to the callable. Optional fields that are nil are *omitted*,
    /// not serialized as `null` — Zod's `.optional()` accepts undefined
    /// only, so a `null` would fail server-side validation.
    public func encodeAsDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "mode": mode,
            "kind": kind,
            "wardId": wardId,
            "speakerId": speakerId,
            "meetingDate": meetingDate,
            "channels": channels,
            "speakerName": speakerName,
            "inviterName": inviterName,
            "wardName": wardName,
            "assignedDate": assignedDate,
            "sentOn": sentOn,
            "bodyMarkdown": bodyMarkdown,
            "footerMarkdown": footerMarkdown,
            "bishopReplyToEmail": bishopReplyToEmail,
            "expiresAtMillis": expiresAtMillis,
        ]
        if let prayerRole { dict["prayerRole"] = prayerRole }
        if let speakerTopic { dict["speakerTopic"] = speakerTopic }
        if let editorStateJson { dict["editorStateJson"] = editorStateJson }
        if let speakerEmail { dict["speakerEmail"] = speakerEmail }
        if let speakerPhone { dict["speakerPhone"] = speakerPhone }
        if let useTestingNumber, useTestingNumber == true { dict["useTestingNumber"] = true }
        return dict
    }

    /// Monday 00:00 in the sender's local time, on the day after the
    /// meeting Sunday. Port of `computeExpiresAt` at
    /// `src/features/templates/utils/sendSpeakerInvitation.ts:120-127`.
    /// Falls back to "now" for malformed inputs — matches the web's
    /// permissive contract (the server will reject an already-past
    /// expiry anyway).
    public static func computeExpiresAt(
        meetingDate: String,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) -> Int64 {
        let parts = meetingDate.split(separator: "-").map { Int($0) }
        guard parts.count == 3,
              let year = parts[0], let month = parts[1], let day = parts[2]
        else {
            return Int64(Date().timeIntervalSince1970 * 1000)
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day + 1   // Monday after the Sunday meeting
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = timeZone
        var cal = calendar
        cal.timeZone = timeZone
        guard let date = cal.date(from: components) else {
            return Int64(Date().timeIntervalSince1970 * 1000)
        }
        return Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func trimToNil(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
