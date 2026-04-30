import Foundation
import Testing
@testable import StewardCore

/// Pure port of the web's `buildMessagePermissions` at
/// `src/features/invitations/utils/messageActions.ts:59-104`. The two
/// load-bearing rules are: (1) only the last `RECENT_EDITABLE_WINDOW`
/// messages are deletable / editable, and (2) the 24-hour clock from
/// `dateCreated` overrides the count-based window so older messages
/// can't be retracted even if they're still in-window. The window
/// previously sat at 30 min; iOS extended it to 24h to cover
/// "noticed mistake later in the day" while keeping the recent-N cap
/// as the structural guard against deep-history rewriting.

@Suite("MessagePermissions — when delete + edit affordances appear on a message")
struct MessagePermissionsTests {

    private let bishop = "uid:bishop"
    private let otherBishop = "uid:other-bishop"
    private let speaker = "speaker:invitationId"

    private var now: Date { Date(timeIntervalSince1970: 1_745_000_000) }

    private func msg(
        sid: String = "m",
        index: Int = 0,
        author: String,
        ageMinutes: Int = 1,
        attributes: ChatMessage.Attributes? = nil
    ) -> ChatMessage {
        let date = now.addingTimeInterval(-Double(ageMinutes * 60))
        return ChatMessage(
            sid: sid, index: index, author: author, body: "x",
            dateCreated: date, attributes: attributes
        )
    }

    @Test("Bishop can delete their own recent message")
    func ownRecentDeletable() {
        let m = msg(sid: "a", author: bishop, ageMinutes: 1)
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: [m], now: now)
        #expect(perms.canDelete(m))
    }

    @Test("Bishop can delete another bishop's recent message — same-side rule")
    func sameSideDeletable() {
        let m = msg(sid: "a", author: otherBishop, ageMinutes: 1)
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: [m], now: now)
        #expect(perms.canDelete(m))
    }

    @Test("Bishop cannot delete a speaker's message — never cross-side")
    func crossSideBlocked() {
        let m = msg(sid: "a", author: speaker, ageMinutes: 1)
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: [m], now: now)
        #expect(perms.canDelete(m) == false)
    }

    @Test("Speaker can only delete their own messages — strict identity match")
    func speakerCanOnlyDeleteOwn() {
        let speakerMsg = msg(sid: "a", author: speaker, ageMinutes: 1)
        let bishopMsg = msg(sid: "b", author: bishop, ageMinutes: 1)
        let perms = MessagePermissions.build(
            currentIdentity: speaker,
            messages: [speakerMsg, bishopMsg],
            now: now
        )
        #expect(perms.canDelete(speakerMsg))
        #expect(perms.canDelete(bishopMsg) == false)
    }

    @Test(
        "Window boundary — within 24h is deletable, past 24h is not (even within the recent-N window)",
        arguments: [
            (label: "5 min after — easy delete",          ageMinutes: 5,            canDelete: true),
            (label: "23h 59m — last minute before expiry", ageMinutes: 23 * 60 + 59, canDelete: true),
            (label: "24h 01m — just past expiry",          ageMinutes: 24 * 60 + 1,  canDelete: false),
            (label: "25h — solidly past expiry",           ageMinutes: 25 * 60,      canDelete: false),
        ]
    )
    func windowBoundary(label: String, ageMinutes: Int, canDelete: Bool) {
        let m = msg(sid: "a", author: bishop, ageMinutes: ageMinutes)
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: [m], now: now)
        #expect(perms.canDelete(m) == canDelete, "\(label): canDelete should be \(canDelete)")
        #expect(perms.canEdit(m) == canDelete, "\(label): canEdit should also be \(canDelete) (same window)")
    }

    @Test("Past the recent-N window, delete is blocked even if the message is fresh")
    func recentWindowDeleteCap() {
        // 6 messages — only the last 5 are deletable. The first should
        // be blocked despite being seconds-old.
        let messages = (0..<6).map { i in
            msg(sid: "m\(i)", index: i, author: bishop, ageMinutes: 1)
        }
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: messages, now: now)
        #expect(perms.canDelete(messages[0]) == false, "first message past the recent-5 window is not deletable")
        #expect(perms.canDelete(messages[1]))
    }

    @Test("Edit window walks the user's last N own messages, not the thread's last N")
    func editWindowIsPerAuthor() {
        // 5 speaker messages followed by 1 bishop message. The bishop's
        // last edit window walks back through their own — i.e. only
        // their single message counts, the speaker's are skipped.
        var messages: [ChatMessage] = []
        for i in 0..<5 {
            messages.append(msg(sid: "s\(i)", index: i, author: speaker, ageMinutes: 1))
        }
        let bishopMessage = msg(sid: "b", index: 5, author: bishop, ageMinutes: 1)
        messages.append(bishopMessage)

        let perms = MessagePermissions.build(currentIdentity: bishop, messages: messages, now: now)
        // Speaker messages are not the bishop's — never editable
        #expect(perms.canEdit(messages[0]) == false)
        // Their own — editable
        #expect(perms.canEdit(bishopMessage))
    }

    @Test("Status-change system messages are never deletable or editable")
    func systemMessagesBlocked() {
        let m = msg(
            sid: "a", author: bishop, ageMinutes: 1,
            attributes: .statusChange(status: "confirmed")
        )
        let perms = MessagePermissions.build(currentIdentity: bishop, messages: [m], now: now)
        #expect(perms.canDelete(m) == false)
        #expect(perms.canEdit(m) == false)
    }

    @Test("Quick-action response messages are never deletable")
    func responseMessagesBlocked() {
        let m = msg(
            sid: "a", author: speaker, ageMinutes: 1,
            attributes: .response(answer: "yes", reason: nil)
        )
        let perms = MessagePermissions.build(currentIdentity: speaker, messages: [m], now: now)
        #expect(perms.canDelete(m) == false)
        #expect(perms.canEdit(m) == false)
    }

    @Test("nil currentIdentity returns predicates that always deny")
    func nilIdentityDeniesAll() {
        let m = msg(sid: "a", author: bishop, ageMinutes: 1)
        let perms = MessagePermissions.build(currentIdentity: nil, messages: [m], now: now)
        #expect(perms.canDelete(m) == false)
        #expect(perms.canEdit(m) == false)
    }
}
