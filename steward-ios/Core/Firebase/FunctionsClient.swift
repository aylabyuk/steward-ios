import Foundation
import StewardCore

#if canImport(FirebaseFunctions)
import FirebaseFunctions

/// Firebase Functions callable invocations. Mirrors `Core/Firestore/InvitationsClient.swift`'s
/// `enum + static methods` style — no instance, no DI plumbing, no mock seam at this
/// layer (the testable seam lives in `StewardCore` via the `*Request.encodeAsDictionary()`
/// and `*Response.decode(from:)` helpers, which round-trip without Firebase).
///
/// All methods talk to the Functions SDK that `App/FirebaseSetup.swift` already
/// wires through to the local emulator when `EmulatorConfig.isEnabled`.
enum FunctionsClient {

    /// Bishop-side token mint for Twilio Conversations. Server-side dispatch
    /// in `functions/src/issueSpeakerSession.ts:46-71`. The bishop's Firebase
    /// auth token implies the bishopric branch — we just send `{ wardId }`
    /// (and optionally `invitationId` to trigger the participant backfill
    /// described in `BishopInvitationChat.tsx:97-101`).
    static func issueSpeakerSession(
        wardId: String,
        invitationId: String? = nil
    ) async throws -> IssueSpeakerSessionResponse {
        var payload: [String: Any] = ["wardId": wardId]
        if let invitationId { payload["invitationId"] = invitationId }
        let result = try await Functions.functions()
            .httpsCallable("issueSpeakerSession")
            .call(payload)
        return try IssueSpeakerSessionResponse.decode(from: result.data)
    }

    /// Mints a `speakerInvitations/{id}` doc + Twilio Conversation, snapshots
    /// the active bishopric roster onto the invitation, hashes the capability
    /// token, and dispatches delivery via the requested channels (or none, if
    /// the bishop is delivering out of band). Server-side at
    /// `functions/src/sendSpeakerInvitation.ts`.
    static func sendSpeakerInvitation(
        _ request: SendSpeakerInvitationRequest
    ) async throws -> SendSpeakerInvitationResponse {
        let payload = try request.encodeAsDictionary()
        let result = try await Functions.functions()
            .httpsCallable("sendSpeakerInvitation")
            .call(payload)
        return try SendSpeakerInvitationResponse.decode(from: result.data)
    }
}

#endif
