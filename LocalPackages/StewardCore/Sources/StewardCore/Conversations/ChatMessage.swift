import Foundation

/// Twilio-agnostic chat message value type. Adapted from
/// `TCHMessage` (Twilio's iOS SDK class) by the app target's chat
/// client; tests + pure-port helpers consume this shape directly.
/// Mirrors the web's `ChatMessage` at
/// `src/features/invitations/hooks/useConversation.ts:11-20`.
public struct ChatMessage: Sendable, Equatable, Hashable, Identifiable {
    /// Twilio's stable per-message identifier. Used as the SwiftUI
    /// `id` and the cache key for `MessagePermissions` predicates.
    public let sid: String
    /// Twilio's monotonic per-conversation index. The unread divider
    /// pivots on this, not on `sid` (which is opaque).
    public let index: Int
    /// Participant identity that authored the message — `uid:{uid}`
    /// for bishopric, `speaker:{invitationId}` for the speaker side.
    public let author: String
    /// The plain-text message body. Markdown is rendered by the
    /// bubble view; structural messages (responses, status-change
    /// notices) use this verbatim.
    public let body: String
    public let dateCreated: Date?
    /// Stamped only when the message was edited after creation. UI
    /// shows an "Edited" label when this is later than `dateCreated`.
    public let dateUpdated: Date?
    public let attributes: Attributes?

    public init(
        sid: String,
        index: Int,
        author: String,
        body: String,
        dateCreated: Date?,
        dateUpdated: Date? = nil,
        attributes: Attributes? = nil
    ) {
        self.sid = sid
        self.index = index
        self.author = author
        self.body = body
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.attributes = attributes
    }

    public var id: String { sid }

    public var wasEdited: Bool {
        guard let dateCreated, let dateUpdated else { return false }
        return dateUpdated > dateCreated
    }

    /// Structured payload Twilio carries on each message under
    /// `attributes`. Mirrors the web's discriminated union — speakers
    /// post quick-action replies (`responseType: yes/no`), the bishop
    /// posts status-change notices (`kind: status-change`), and the
    /// initial invitation message itself is tagged (`kind:
    /// invitation`). Structural messages can't be edited or deleted.
    public enum Attributes: Sendable, Equatable, Hashable {
        case response(answer: String, reason: String?)
        case invitation
        case statusChange(status: String)
    }
}

extension ChatMessage.Attributes {
    /// Decode from the JSON-decoded dict Twilio's SDK hands back via
    /// `TCHMessage.attributes`. Returns nil for shapes we don't
    /// recognize so unknown future kinds round-trip safely.
    public static func parse(_ raw: [String: Any]?) -> ChatMessage.Attributes? {
        guard let raw else { return nil }
        if let kind = raw["kind"] as? String {
            if kind == "invitation" { return .invitation }
            if kind == "status-change", let status = raw["status"] as? String {
                return .statusChange(status: status)
            }
        }
        if let answer = raw["responseType"] as? String, answer == "yes" || answer == "no" {
            let reason = raw["reason"] as? String
            return .response(answer: answer, reason: reason)
        }
        return nil
    }

    /// True for messages that anchor audit / response history. The
    /// thread renders these without bubble affordances, and
    /// `MessagePermissions` blocks edit/delete on them.
    public var isStructural: Bool {
        switch self {
        case .response, .invitation, .statusChange: return true
        }
    }
}

/// One row to render in the thread, in display order. The builder
/// transforms a flat `[ChatMessage]` into this typed sequence —
/// SwiftUI then iterates and switches on `kind`. Mirrors the web's
/// `ThreadItem` discriminated union in
/// `src/features/invitations/utils/threadItems.ts:11-15`.
public enum ThreadItem: Sendable, Equatable, Hashable, Identifiable {
    /// Day separator ("Today" / "Yesterday" / "Saturday" / "Mar 15").
    case day(key: String, label: String)
    /// Inserted once, just before the first unread non-mine message.
    case unread(key: String)
    /// "Assignment confirmed" / "Assignment updated to declined" —
    /// rendered as a centered rule-label-rule by `SystemNoticeView`.
    case system(sid: String, body: String, status: String)
    /// Consecutive same-author messages collapsed into one bubble
    /// stack. Top-level switching happens here.
    case group(MessageGroup)

    public var id: String {
        switch self {
        case let .day(key, _):              return key
        case let .unread(key):              return key
        case let .system(sid, _, _):        return "system-\(sid)"
        case let .group(group):             return "group-\(group.key)"
        }
    }
}

/// One avatar + bubble-stack rendered by `ConversationGroupView`.
/// Author identity is the grouping key (consecutive messages from the
/// same `author` get folded together).
public struct MessageGroup: Sendable, Equatable, Hashable, Identifiable {
    public let key: String
    public let author: String
    public let mine: Bool
    public let info: AuthorInfo
    public let messages: [ChatMessage]

    public init(
        key: String,
        author: String,
        mine: Bool,
        info: AuthorInfo,
        messages: [ChatMessage]
    ) {
        self.key = key
        self.author = author
        self.mine = mine
        self.info = info
        self.messages = messages
    }

    public var id: String { key }
}

/// Display metadata for a participant identity. Resolved from the
/// invitation snapshot (`bishopricParticipants`) + the speaker's
/// invitation doc + Twilio participant attributes overlay; falls back
/// to a generic label if unknown.
public struct AuthorInfo: Sendable, Equatable, Hashable {
    public let displayName: String
    /// `"speaker"`, `"bishopric"`, `"clerk"`. Free-form for
    /// forward-compat. Drives the eyebrow label on the bubble group.
    public let role: String?
    public let photoURL: URL?
    public let email: String?

    public init(
        displayName: String,
        role: String? = nil,
        photoURL: URL? = nil,
        email: String? = nil
    ) {
        self.displayName = displayName
        self.role = role
        self.photoURL = photoURL
        self.email = email
    }
}
