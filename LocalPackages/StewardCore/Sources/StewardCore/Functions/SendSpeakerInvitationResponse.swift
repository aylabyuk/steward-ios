import Foundation

/// Response from the `sendSpeakerInvitation` Cloud Function. Mirrors the
/// fresh-mode shape at `functions/src/sendSpeakerInvitation.types.ts:74-81`
/// — the rotate-mode response is a separate shape and not used on iOS yet.
public struct SendSpeakerInvitationResponse: Decodable, Sendable, Equatable {
    public let mode: String
    /// The server's `token` field is misleadingly named — it carries the
    /// Firestore invitation doc id, not the plaintext capability token.
    /// See `speakerInvitation.ts:74-78`. Aliased here to its real meaning
    /// so app-target callers don't have to puzzle out the indirection.
    public let invitationId: String
    public let conversationSid: String
    public let deliveryRecord: [DeliveryEntry]

    public struct DeliveryEntry: Decodable, Sendable, Equatable {
        public let channel: String
        public let status: String
        public let providerId: String?
        public let error: String?

        public init(channel: String, status: String, providerId: String? = nil, error: String? = nil) {
            self.channel = channel
            self.status = status
            self.providerId = providerId
            self.error = error
        }
    }

    public init(
        mode: String,
        invitationId: String,
        conversationSid: String,
        deliveryRecord: [DeliveryEntry]
    ) {
        self.mode = mode
        self.invitationId = invitationId
        self.conversationSid = conversationSid
        self.deliveryRecord = deliveryRecord
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case invitationId = "token"   // back-compat with the misleading server field name
        case conversationSid
        case deliveryRecord
    }

    public static func decode(from data: Data) throws -> SendSpeakerInvitationResponse {
        try JSONDecoder().decode(SendSpeakerInvitationResponse.self, from: data)
    }

    public static func decode(from dict: Any) throws -> SendSpeakerInvitationResponse {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try decode(from: data)
    }
}
