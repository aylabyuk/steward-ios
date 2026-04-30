import Foundation
import Testing
@testable import StewardCore

/// Form-output validation. Mirrors the web's loose Zod rules at
/// src/lib/types/meeting.ts:149-167 (speakers) and :178-193 (prayers):
/// name min 1, email valid-or-empty, phone free-form, role required for
/// speakers but implicit (carried by the slot) for prayers.

private func draft(
    kind: SlotKind = .speaker,
    name: String = "Sarah Bensen",
    email: String? = nil,
    phone: String? = nil,
    topic: String? = nil,
    role: SpeakerRole? = .member
) -> InvitationDraft {
    InvitationDraft(
        kind: kind,
        wardId: "stv1",
        meetingDate: "2026-05-17",
        wardName: "Eglinton Ward",
        inviterName: "Bishop Smith",
        name: name,
        email: email,
        phone: phone,
        topic: topic,
        role: role
    )
}

@Suite("InvitationDraft validation — what the form rejects before going to preview")
struct InvitationDraftValidationTests {

    @Test("A speaker with name + role passes")
    func speakerHappyPath() throws {
        let result = draft().validate()
        #expect(throws: Never.self) { try result.get() }
    }

    @Test("A prayer with just a name passes — role is implicit from the slot")
    func prayerHappyPath() throws {
        let result = draft(kind: .openingPrayer, role: nil).validate()
        #expect(throws: Never.self) { try result.get() }
    }

    @Test("Empty name fails — the assignee name is the one required field")
    func emptyName() {
        let result = draft(name: "").validate()
        #expect(throws: InvitationDraft.ValidationError.nameRequired) { try result.get() }
    }

    @Test("Whitespace-only name fails (after trim)")
    func whitespaceName() {
        let result = draft(name: "   ").validate()
        #expect(throws: InvitationDraft.ValidationError.nameRequired) { try result.get() }
    }

    @Test("Empty email string is treated as 'no email' — matches web's z.literal('') escape hatch")
    func emptyEmailIsOk() throws {
        let result = draft(email: "").validate()
        #expect(throws: Never.self) { try result.get() }
    }

    @Test("Invalid email format fails")
    func invalidEmail() {
        let result = draft(email: "not-an-email").validate()
        #expect(throws: InvitationDraft.ValidationError.invalidEmail) { try result.get() }
    }

    @Test("A valid email passes")
    func validEmail() throws {
        let result = draft(email: "sarah@example.com").validate()
        #expect(throws: Never.self) { try result.get() }
    }

    @Test(
        "Phone is free-form — anything the bishop types is accepted, sanitization happens at send time",
        arguments: [
            "555-0123",
            "(416) 555-0123",
            "+1 416 555 0123",
            "  ",
            "",
        ]
    )
    func phoneFreeForm(phone: String) throws {
        let result = draft(phone: phone).validate()
        #expect(throws: Never.self) { try result.get() }
    }

    @Test("Speakers without a role fail — web requires SPEAKER_ROLES selection")
    func speakerNeedsRole() {
        let result = draft(role: nil).validate()
        #expect(throws: InvitationDraft.ValidationError.roleRequired) { try result.get() }
    }
}

@Suite("InvitationDraft canSend — what the share/invite buttons gate on")
struct InvitationDraftSendabilityTests {

    @Test("A draft with no email and no phone cannot be sent — Mark Invited still works")
    func noChannel() {
        #expect(draft().canSend == false)
    }

    @Test("Either email or phone is enough for the share path to make sense")
    func eitherChannel() {
        #expect(draft(email: "x@example.com").canSend)
        #expect(draft(phone: "555-0123").canSend)
        #expect(draft(email: "x@example.com", phone: "555-0123").canSend)
    }

    @Test("Empty-string email or phone counts as no channel")
    func emptyStringDoesntCount() {
        #expect(draft(email: "", phone: "").canSend == false)
    }
}
