import Foundation

/// What the iOS bishop client receives when it calls
/// `issueSpeakerSession({ wardId })` — the bishopric branch in
/// `functions/src/issueSpeakerSession.ts:53-57` (mintBishopricSession).
/// The speaker-side branch returns additional fields (`firebaseCustomToken`,
/// `phoneLast4`, etc.) that iOS never produces but the decoder ignores.
public struct IssueSpeakerSessionResponse: Decodable, Sendable, Equatable {
    public let status: String
    public let twilioToken: String
    public let identity: String
    public let expiresInSeconds: Int

    public init(
        status: String,
        twilioToken: String,
        identity: String,
        expiresInSeconds: Int
    ) {
        self.status = status
        self.twilioToken = twilioToken
        self.identity = identity
        self.expiresInSeconds = expiresInSeconds
    }

    public static func decode(from data: Data) throws -> IssueSpeakerSessionResponse {
        try JSONDecoder().decode(IssueSpeakerSessionResponse.self, from: data)
    }

    /// Decode from the dictionary the Firebase Functions SDK hands back
    /// (after `HTTPSCallableResult.data`). The SDK already JSON-decodes
    /// the response — we just re-shape via JSONSerialization since the
    /// SDK delivers `Any`, not a typed struct.
    public static func decode(from dict: Any) throws -> IssueSpeakerSessionResponse {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try decode(from: data)
    }
}
