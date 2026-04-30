import Foundation
import Testing
@testable import StewardCore

/// Decoding parity with the web's `speakerInvitationSchema` at
/// `src/lib/types/speakerInvitation.ts:67-183`. iOS only consumes a
/// subset (the chat sheet needs conversationSid + response +
/// speakerLastSeenAt + currentSpeakerStatus + bishopricParticipants),
/// so the model is intentionally narrower than the web's Zod schema.

@Suite("SpeakerInvitation decoding — what the chat sheet needs from the doc")
struct SpeakerInvitationDecodingTests {

    @Test("A fully-populated doc decodes the chat-sheet-relevant fields")
    func happyPath() throws {
        // Mirrors what `FirestoreDocSource` would feed in: Firestore
        // Timestamps already converted to ISO8601 strings by the
        // sanitizer in `FirestoreCollectionSource.swift`.
        let json = """
        {
            "speakerName": "Sister Daisylene Oliquino",
            "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "spk_42"},
            "conversationSid": "CH001",
            "currentSpeakerStatus": "invited",
            "speakerLastSeenAt": "2026-04-27T14:00:00Z",
            "bishopricParticipants": [
                {"uid": "abc", "displayName": "Bishop Smith", "role": "bishopric", "email": "smith@e2e.local"},
                {"uid": "def", "displayName": "Brother Jensen", "role": "clerk"}
            ],
            "response": {
                "answer": "yes",
                "reason": "Happy to.",
                "respondedAt": "2026-04-27T13:30:00Z",
                "actorUid": "speaker:invitation_id",
                "actorEmail": "daisy@example.com"
            },
            "expiresAt": "2026-05-18T04:00:00Z",
            "kind": "speaker"
        }
        """.data(using: .utf8)!
        let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
        #expect(invitation.speakerName == "Sister Daisylene Oliquino")
        #expect(invitation.speakerRef.meetingDate == "2026-05-17")
        #expect(invitation.speakerRef.speakerId == "spk_42")
        #expect(invitation.conversationSid == "CH001")
        #expect(invitation.currentSpeakerStatus == "invited")
        #expect(invitation.speakerLastSeenAt == "2026-04-27T14:00:00Z")
        #expect(invitation.bishopricParticipants.count == 2)
        #expect(invitation.bishopricParticipants[0].uid == "abc")
        #expect(invitation.bishopricParticipants[0].role == "bishopric")
        #expect(invitation.response?.answer == "yes")
        #expect(invitation.response?.reason == "Happy to.")
        #expect(invitation.response?.acknowledgedAt == nil)
        #expect(invitation.kind == "speaker")
    }

    @Test("Missing kind defaults to 'speaker' — back-compat with pre-prayer-flow docs")
    func kindDefault() throws {
        let json = #"""
        {
            "speakerName": "X",
            "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "spk_1"},
            "bishopricParticipants": []
        }
        """#.data(using: .utf8)!
        let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
        #expect(invitation.kind == "speaker")
    }

    @Test("Prayer-kind invitations carry a prayerRole — schema discriminator")
    func prayerKind() throws {
        let json = """
        {
            "speakerName": "Brother Jensen",
            "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "opening"},
            "kind": "prayer",
            "prayerRole": "opening",
            "bishopricParticipants": []
        }
        """.data(using: .utf8)!
        let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
        #expect(invitation.kind == "prayer")
        #expect(invitation.prayerRole == "opening")
    }

    @Test("Pre-Twilio-rollout invitations missing conversationSid still decode (chat reads as unavailable)")
    func conversationSidOptional() throws {
        let json = #"""
        {
            "speakerName": "Sister Davis",
            "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "spk_1"},
            "bishopricParticipants": []
        }
        """#.data(using: .utf8)!
        let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
        #expect(invitation.conversationSid == nil)
    }

    @Test("Response answer is captured verbatim — banner text branches on it")
    func responseAnswers() throws {
        for answer in ["yes", "no"] {
            let json = """
            {
                "speakerName": "X",
                "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "spk_1"},
                "bishopricParticipants": [],
                "response": {
                    "answer": "\(answer)",
                    "respondedAt": "2026-04-27T13:30:00Z",
                    "actorUid": "speaker:1"
                }
            }
            """.data(using: .utf8)!
            let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
            #expect(invitation.response?.answer == answer)
        }
    }

    @Test("BishopricParticipant decodes without an email — earlier docs may lack it")
    func participantEmailOptional() throws {
        let json = """
        {
            "speakerName": "X",
            "speakerRef": {"meetingDate": "2026-05-17", "speakerId": "spk_1"},
            "bishopricParticipants": [
                {"uid": "abc", "displayName": "Bishop Smith", "role": "bishopric"}
            ]
        }
        """.data(using: .utf8)!
        let invitation = try JSONDecoder().decode(SpeakerInvitation.self, from: json)
        #expect(invitation.bishopricParticipants[0].email == nil)
    }
}
