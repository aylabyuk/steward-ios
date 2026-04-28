import Foundation
import Testing
@testable import StewardCore

/// Decoding parity with the bishopric branch of `issueSpeakerSession` at
/// functions/src/issueSpeakerSession.ts:53-57 (calls `mintBishopricSession`,
/// which returns `{ status: "ready", twilioToken, identity, expiresInSeconds }`).

@Suite("IssueSpeakerSessionResponse — what the bishop receives")
struct IssueSpeakerSessionResponseDecodingTests {

    @Test("Bishop session decodes the four fields the TwilioChatClient consumes")
    func bishopSessionDecodes() throws {
        let json = """
        {
          "status": "ready",
          "twilioToken": "eyJhbGc...fake",
          "identity": "uid:G2Bcy1N7aLAAkZd94WYqDwJ9cYwV",
          "expiresInSeconds": 3600
        }
        """
        let res = try IssueSpeakerSessionResponse.decode(from: Data(json.utf8))
        #expect(res.status == "ready")
        #expect(res.twilioToken == "eyJhbGc...fake")
        #expect(res.identity == "uid:G2Bcy1N7aLAAkZd94WYqDwJ9cYwV")
        #expect(res.expiresInSeconds == 3600)
    }

    @Test("A ready bishop response with the `firebaseCustomToken` field present (the speaker-shape fallback) still decodes")
    func tolerantToExtraFields() throws {
        // Speaker-side responses from the same Cloud Function include
        // `firebaseCustomToken`. The bishop branch never returns that
        // field, but the iOS decoder shouldn't choke if the server
        // ever changes shape — extra fields are fine.
        let json = """
        {
          "status": "ready",
          "twilioToken": "tok",
          "identity": "uid:abc",
          "expiresInSeconds": 3600,
          "firebaseCustomToken": ""
        }
        """
        let res = try IssueSpeakerSessionResponse.decode(from: Data(json.utf8))
        #expect(res.status == "ready")
    }
}

@Suite("SendSpeakerInvitationResponse — what 'Mark as Invited' receives")
struct SendSpeakerInvitationResponseDecodingTests {

    @Test("Fresh-mode response surfaces the conversationSid and the invitationId (returned as `token`)")
    func freshModeDecodes() throws {
        let json = """
        {
          "mode": "fresh",
          "token": "inv_abc123",
          "conversationSid": "CH00000000000000000000000000000001",
          "deliveryRecord": []
        }
        """
        let res = try SendSpeakerInvitationResponse.decode(from: Data(json.utf8))
        #expect(res.mode == "fresh")
        #expect(res.invitationId == "inv_abc123",
                "the server's `token` field is the invitationId — see speakerInvitation.ts:74-78")
        #expect(res.conversationSid == "CH00000000000000000000000000000001")
        #expect(res.deliveryRecord.isEmpty)
    }

    @Test("Delivery record entries decode their channel + status")
    func deliveryRecordDecodes() throws {
        let json = """
        {
          "mode": "fresh",
          "token": "inv_abc123",
          "conversationSid": "CH001",
          "deliveryRecord": [
            { "channel": "sms", "status": "sent", "providerId": "SM001", "at": "2026-04-28T12:00:00Z" },
            { "channel": "email", "status": "failed", "error": "no-key", "at": "2026-04-28T12:00:01Z" }
          ]
        }
        """
        let res = try SendSpeakerInvitationResponse.decode(from: Data(json.utf8))
        #expect(res.deliveryRecord.count == 2)
        #expect(res.deliveryRecord[0].channel == "sms")
        #expect(res.deliveryRecord[0].status == "sent")
        #expect(res.deliveryRecord[1].channel == "email")
        #expect(res.deliveryRecord[1].status == "failed")
    }
}
