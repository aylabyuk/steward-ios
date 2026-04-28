import Foundation

/// Pure transform `[ChatMessage]` → `[ThreadItem]`. Mirrors the web's
/// `buildThreadItems` at
/// `src/features/invitations/utils/threadItems.ts:31-85`.
///
/// Behaviour pinned by `ThreadItemBuilderTests`:
///   * Inserts a `.day(label:)` divider whenever the date rolls over,
///     anchored on `now` for the "Today" / "Yesterday" / weekday
///     buckets.
///   * Collapses consecutive same-author messages into one
///     `MessageGroup`.
///   * Extracts `attributes == .statusChange(status: confirmed|declined)`
///     messages as `.system` items, breaking the surrounding group.
///   * Inserts an `.unread` divider once, just before the first
///     non-mine message at or after `firstUnreadIndex`.
///   * Falls back to "Speaker" / "Bishopric" / "Unknown" when an
///     identity isn't in the `authors` map.
public enum ThreadItemBuilder {

    public static func build(
        messages: [ChatMessage],
        currentIdentity: String?,
        authors: [String: AuthorInfo],
        firstUnreadIndex: Int?,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [ThreadItem] {
        var items: [ThreadItem] = []
        var lastDayKey: String? = nil
        var unreadInserted = false
        var currentGroup: MessageGroup? = nil

        func flushGroup() {
            if let group = currentGroup {
                items.append(.group(group))
            }
            currentGroup = nil
        }

        for message in messages {
            let dKey = dayKey(message.dateCreated, calendar: calendar)
            if dKey != lastDayKey {
                flushGroup()
                items.append(
                    .day(
                        key: "day-\(dKey)",
                        label: dayLabel(message.dateCreated, now: now, calendar: calendar, locale: locale)
                    )
                )
                lastDayKey = dKey
            }

            // Status-change → centered system notice, no bubble.
            if case let .statusChange(status) = message.attributes,
               status == "confirmed" || status == "declined" {
                flushGroup()
                items.append(.system(sid: message.sid, body: message.body, status: status))
                continue
            }

            let mine = message.author == currentIdentity
            if !unreadInserted,
               !mine,
               let firstUnreadIndex,
               message.index >= firstUnreadIndex {
                flushGroup()
                items.append(.unread(key: "unread-\(message.index)"))
                unreadInserted = true
            }

            if let group = currentGroup, group.author == message.author {
                currentGroup = MessageGroup(
                    key: group.key,
                    author: group.author,
                    mine: group.mine,
                    info: group.info,
                    messages: group.messages + [message]
                )
                continue
            }

            flushGroup()
            currentGroup = MessageGroup(
                key: message.sid,
                author: message.author,
                mine: mine,
                info: authors[message.author] ?? fallbackAuthor(for: message.author),
                messages: [message]
            )
        }
        flushGroup()
        return items
    }

    private static func dayKey(_ date: Date?, calendar: Calendar) -> String {
        guard let date else { return "no-date" }
        var c = calendar
        c.timeZone = .current
        let components = c.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func dayLabel(
        _ date: Date?,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        guard let date else { return "Earlier" }
        var c = calendar
        c.timeZone = .current
        let today = c.startOfDay(for: now)
        let that = c.startOfDay(for: date)
        let diffDays = c.dateComponents([.day], from: that, to: today).day ?? 0
        if diffDays == 0 { return "Today" }
        if diffDays == 1 { return "Yesterday" }
        if diffDays > 0 && diffDays < 7 {
            var style = Date.FormatStyle().weekday(.wide).locale(locale)
            style.timeZone = c.timeZone
            return date.formatted(style)
        }
        let nowYear = c.dateComponents([.year], from: now).year
        let thatYear = c.dateComponents([.year], from: date).year
        if nowYear == thatYear {
            var style = Date.FormatStyle().month(.abbreviated).day().locale(locale)
            style.timeZone = c.timeZone
            return date.formatted(style)
        }
        var style = Date.FormatStyle().month(.abbreviated).day().year().locale(locale)
        style.timeZone = c.timeZone
        return date.formatted(style)
    }

    /// Best-effort label for identities we don't have a snapshot for —
    /// keeps the thread readable even if the invitation participant
    /// list is missing or a participant joined late.
    private static func fallbackAuthor(for identity: String) -> AuthorInfo {
        if identity.hasPrefix("speaker:") {
            return AuthorInfo(displayName: "Speaker", role: "speaker")
        }
        if identity.hasPrefix("uid:") {
            return AuthorInfo(displayName: "Bishopric", role: "bishopric")
        }
        return AuthorInfo(displayName: "Unknown")
    }
}
