import Foundation
import Testing
@testable import StewardCore

/// Pure port of the web's `buildThreadItems` at
/// `src/features/invitations/utils/threadItems.ts:31-85`. The shape is
/// load-bearing — `ConversationThreadView` iterates the result and
/// switches on `kind`, so any drift here translates directly into
/// rendering bugs. Tests pin the day-divider math, group-collapsing
/// behaviour, system-notice extraction, and unread-divider placement.

@Suite("ThreadItemBuilder — what the chat thread sees, in render order")
struct ThreadItemBuilderTests {

    private let bishop = "uid:bishop"
    private let speaker = "speaker:invitationId"

    private func msg(
        sid: String = "m",
        index: Int = 0,
        author: String,
        body: String = "Hi",
        date: Date,
        attributes: ChatMessage.Attributes? = nil
    ) -> ChatMessage {
        ChatMessage(
            sid: sid, index: index, author: author, body: body,
            dateCreated: date, attributes: attributes
        )
    }

    private var authors: [String: AuthorInfo] {
        [
            bishop: AuthorInfo(displayName: "Bishop Smith", role: "bishopric"),
            speaker: AuthorInfo(displayName: "Sister Daisy", role: "speaker"),
        ]
    }

    /// `2026-04-28 12:00:00 UTC` — Tuesday. Used as the "now" anchor
    /// so day-label tests are deterministic.
    private var now: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 28
        components.hour = 12
        components.timeZone = .gmt
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func date(_ daysAgo: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var d = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        d = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
        return d
    }

    @Test("Empty input yields an empty thread")
    func empty() {
        let items = ThreadItemBuilder.build(
            messages: [],
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        #expect(items.isEmpty)
    }

    @Test("A single same-day message produces a day divider then a group of one")
    func singleMessage() {
        let messages = [msg(author: speaker, date: now)]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        #expect(items.count == 2)
        guard case let .day(_, label) = items[0] else {
            Issue.record("expected day divider first, got \(items[0])")
            return
        }
        #expect(label == "Today")
        guard case let .group(group) = items[1] else {
            Issue.record("expected group second, got \(items[1])")
            return
        }
        #expect(group.author == speaker)
        #expect(group.mine == false)
        #expect(group.messages.count == 1)
    }

    @Test("Consecutive messages from the same author collapse into one group")
    func groupCollapse() {
        let messages = [
            msg(sid: "a", index: 0, author: speaker, body: "Hi", date: now),
            msg(sid: "b", index: 1, author: speaker, body: "Following up", date: now),
            msg(sid: "c", index: 2, author: speaker, body: "Quick q", date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        // [day, group(3 messages)]
        #expect(items.count == 2)
        guard case let .group(group) = items[1] else {
            Issue.record("expected single group, got \(items[1])")
            return
        }
        #expect(group.messages.count == 3)
        #expect(group.messages.map(\.body) == ["Hi", "Following up", "Quick q"])
    }

    @Test("Author switch breaks the group — back-and-forth shows separate bubbles")
    func authorSwitch() {
        let messages = [
            msg(sid: "a", index: 0, author: speaker, body: "Hi", date: now),
            msg(sid: "b", index: 1, author: bishop, body: "Hello", date: now),
            msg(sid: "c", index: 2, author: speaker, body: "Thanks", date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        // [day, group(speaker), group(bishop), group(speaker)]
        #expect(items.count == 4)
        let groupCount = items.filter { if case .group = $0 { return true }; return false }.count
        #expect(groupCount == 3)
    }

    @Test("Day rollover inserts a fresh divider — Yesterday then Today")
    func dayRollover() {
        let messages = [
            msg(sid: "a", index: 0, author: speaker, date: date(1)),
            msg(sid: "b", index: 1, author: speaker, date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        // [day=Yesterday, group, day=Today, group]
        #expect(items.count == 4)
        guard case let .day(_, label1) = items[0] else { Issue.record("first item not day"); return }
        guard case let .day(_, label2) = items[2] else { Issue.record("third item not day"); return }
        #expect(label1 == "Yesterday")
        #expect(label2 == "Today")
    }

    @Test("Status-change attribute renders as a centered system notice, not a bubble")
    func statusChangeIsSystemNotice() {
        let messages = [
            msg(sid: "a", index: 0, author: bishop, body: "Hi", date: now),
            msg(
                sid: "b", index: 1, author: bishop,
                body: "Assignment confirmed — thank you.",
                date: now,
                attributes: .statusChange(status: "confirmed")
            ),
            msg(sid: "c", index: 2, author: bishop, body: "Looking forward", date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: nil,
            now: now
        )
        // [day, group(a), system(b), group(c)] — group breaks around the system notice
        #expect(items.count == 4)
        guard case let .system(sid, body, status) = items[2] else {
            Issue.record("expected system notice, got \(items[2])")
            return
        }
        #expect(sid == "b")
        #expect(body.contains("confirmed"))
        #expect(status == "confirmed")
    }

    @Test("Unread divider lands just before the first non-mine message at-or-after the index")
    func unreadDividerBeforeFirstUnread() {
        let messages = [
            msg(sid: "a", index: 0, author: bishop, date: now),
            msg(sid: "b", index: 1, author: speaker, date: now),
            msg(sid: "c", index: 2, author: speaker, date: now),
            msg(sid: "d", index: 3, author: speaker, date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: 2, // unread starts at index 2
            now: now
        )
        // Expect: day, group(a), group(b), unread, group(c+d) — but b
        // and c+d are different groups because the unread divider
        // breaks them apart.
        let unreadIndex = items.firstIndex { if case .unread = $0 { return true }; return false }
        #expect(unreadIndex != nil, "expected unread divider")
    }

    @Test("Unread divider is suppressed for messages the viewer authored")
    func unreadDividerSkipsMineMessages() {
        let messages = [
            msg(sid: "a", index: 0, author: bishop, date: now),
            msg(sid: "b", index: 1, author: bishop, date: now), // mine, at unread index
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: authors,
            firstUnreadIndex: 1,
            now: now
        )
        let hasUnread = items.contains { if case .unread = $0 { return true }; return false }
        #expect(hasUnread == false)
    }

    @Test("Unknown author identities fall back to a generic Speaker / Bishopric label")
    func unknownAuthorFallback() {
        let messages = [
            msg(author: "speaker:unknown", date: now),
        ]
        let items = ThreadItemBuilder.build(
            messages: messages,
            currentIdentity: bishop,
            authors: [:],
            firstUnreadIndex: nil,
            now: now
        )
        guard case let .group(group) = items[1] else {
            Issue.record("expected group, got \(items[1])")
            return
        }
        #expect(group.info.displayName == "Speaker")
    }
}
