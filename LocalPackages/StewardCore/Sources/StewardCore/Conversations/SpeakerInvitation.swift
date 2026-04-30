import Foundation

/// Codable mirror of the web's `speakerInvitationSchema` at
/// `src/lib/types/speakerInvitation.ts:67-183`, narrowed to the fields
/// the iOS chat sheet consumes. Fields the bishop client reads but
/// the chat doesn't (tokenHash, deliveryRecord, editorStateJson,
/// expiry-token bookkeeping) are intentionally absent — the doc still
/// decodes because Codable ignores unrecognized JSON keys.
///
/// Stored at `wards/{wardId}/speakerInvitations/{invitationId}`.
public struct SpeakerInvitation: Codable, Sendable, Equatable {
    /// Discriminator. Defaults to `"speaker"` for back-compat with
    /// invitations written before the prayer-flow rollout — see
    /// `speakerInvitationSchema.kind` (`.default("speaker")`).
    public let kind: String
    /// Set only when `kind == "prayer"`. Mirrors the participant doc's
    /// role at `wards/{wardId}/meetings/{date}/prayers/{role}`.
    public let prayerRole: String?
    /// Denormalized reference back to the participant doc this
    /// invitation was sent for. The field name is back-compat-driven —
    /// for prayer kinds, `speakerId` holds the role string
    /// (`"opening"` | `"benediction"`), not a doc id.
    public let speakerRef: SpeakerRef
    /// Display name on the chat sheet header.
    public let speakerName: String
    /// Display name of the bishopric member who hit "Send" — surfaced
    /// in the chat banner's "INVITED BY X · DATE" sub-line.
    public let inviterName: String?
    /// ISO8601 string. The chat banner uses this to format the
    /// "INVITED BY X · APR 28" date stamp.
    public let createdAt: String?
    /// Twilio Conversation SID. Absent on pre-#16 invitations and on
    /// rows whose Twilio creation failed — chat reads as "unavailable".
    public let conversationSid: String?
    /// Mirror of the speaker doc's status, written by the bishop's
    /// client whenever they apply a response or use the chat-banner
    /// pills. Lets the speaker page surface up-to-date status without
    /// reading the meeting-scoped speaker doc.
    public let currentSpeakerStatus: String?
    /// ISO8601 string (Firestore Timestamp sanitized by
    /// `FirestoreCollectionSource`). Heartbeat from the speaker's
    /// invite page; the chat banner formats this into "viewing now",
    /// "5 min ago", etc.
    public let speakerLastSeenAt: String?
    /// ISO8601 string. Past-this-time invitations show "expired" in
    /// the chat banner. Pre-rollout invitations may not have it.
    public let expiresAt: String?
    /// Snapshot of the active bishopric/clerk roster at send time.
    /// The chat thread renders these as participants (resolves
    /// `uid:{...}` identities to display names).
    public let bishopricParticipants: [Participant]
    /// Speaker's Yes/No reply. Absent until the speaker hits the
    /// in-app reply button.
    public let response: Response?

    public init(
        kind: String = "speaker",
        prayerRole: String? = nil,
        speakerRef: SpeakerRef,
        speakerName: String,
        inviterName: String? = nil,
        createdAt: String? = nil,
        conversationSid: String? = nil,
        currentSpeakerStatus: String? = nil,
        speakerLastSeenAt: String? = nil,
        expiresAt: String? = nil,
        bishopricParticipants: [Participant] = [],
        response: Response? = nil
    ) {
        self.kind = kind
        self.prayerRole = prayerRole
        self.speakerRef = speakerRef
        self.speakerName = speakerName
        self.inviterName = inviterName
        self.createdAt = createdAt
        self.conversationSid = conversationSid
        self.currentSpeakerStatus = currentSpeakerStatus
        self.speakerLastSeenAt = speakerLastSeenAt
        self.expiresAt = expiresAt
        self.bishopricParticipants = bishopricParticipants
        self.response = response
    }

    public struct SpeakerRef: Codable, Sendable, Equatable {
        public let meetingDate: String
        public let speakerId: String

        public init(meetingDate: String, speakerId: String) {
            self.meetingDate = meetingDate
            self.speakerId = speakerId
        }
    }

    public struct Participant: Codable, Sendable, Equatable {
        public let uid: String
        public let displayName: String
        /// `"bishopric"` or `"clerk"` — drives the eyebrow label on
        /// chat bubbles. Free-form for forward-compat.
        public let role: String?
        public let email: String?

        public init(uid: String, displayName: String, role: String? = nil, email: String? = nil) {
            self.uid = uid
            self.displayName = displayName
            self.role = role
            self.email = email
        }
    }

    public struct Response: Codable, Sendable, Equatable {
        /// `"yes"` or `"no"`.
        public let answer: String
        public let reason: String?
        public let respondedAt: String?
        public let actorUid: String?
        public let actorEmail: String?
        /// Stamped when the bishop hits "Apply" — null until then.
        public let acknowledgedAt: String?
        public let acknowledgedBy: String?

        public init(
            answer: String,
            reason: String? = nil,
            respondedAt: String? = nil,
            actorUid: String? = nil,
            actorEmail: String? = nil,
            acknowledgedAt: String? = nil,
            acknowledgedBy: String? = nil
        ) {
            self.answer = answer
            self.reason = reason
            self.respondedAt = respondedAt
            self.actorUid = actorUid
            self.actorEmail = actorEmail
            self.acknowledgedAt = acknowledgedAt
            self.acknowledgedBy = acknowledgedBy
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind, prayerRole, speakerRef, speakerName
        case inviterName, createdAt, conversationSid
        case currentSpeakerStatus, speakerLastSeenAt, expiresAt
        case bishopricParticipants, response
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "speaker"
        self.prayerRole = try container.decodeIfPresent(String.self, forKey: .prayerRole)
        self.speakerRef = try container.decode(SpeakerRef.self, forKey: .speakerRef)
        self.speakerName = try container.decode(String.self, forKey: .speakerName)
        self.inviterName = try container.decodeIfPresent(String.self, forKey: .inviterName)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.conversationSid = try container.decodeIfPresent(String.self, forKey: .conversationSid)
        self.currentSpeakerStatus = try container.decodeIfPresent(String.self, forKey: .currentSpeakerStatus)
        self.speakerLastSeenAt = try container.decodeIfPresent(String.self, forKey: .speakerLastSeenAt)
        self.expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        self.bishopricParticipants = try container.decodeIfPresent([Participant].self, forKey: .bishopricParticipants) ?? []
        self.response = try container.decodeIfPresent(Response.self, forKey: .response)
    }
}
