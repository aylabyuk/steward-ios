import Foundation

/// Pure port of the web's `buildMessagePermissions` at
/// `src/features/invitations/utils/messageActions.ts:59-104`.
/// Computes whether the current viewer can delete or edit each
/// message, given the structural-vs-conversation rules + the recent-N
/// window + the 30-minute clock.
///
/// Behaviour pinned by `MessagePermissionsTests`. The web's same-side
/// rule applies: bishopric identities can delete any other bishopric
/// message (their own or a colleague's), speakers can only delete
/// their own. Cross-side delete is never allowed. Edit is always
/// strict-identity.
public enum MessagePermissions {

    /// Size of the "recent" sliding window that gates affordances.
    /// Delete uses the thread's last-N (any author); edit uses the
    /// viewer's last-N (own messages only).
    public static let recentEditableWindow: Int = 5

    /// Hard expiry from `dateCreated` — past this, both affordances
    /// hide. iOS uses 24h (web previously sat at 30 min — see
    /// `docs/web-deviations.md`). The longer window covers "noticed
    /// the mistake later in the day"; the recent-N cap above is the
    /// structural guard that prevents deep-history rewriting even
    /// inside the window.
    public static let editDeleteWindowSeconds: TimeInterval = 24 * 60 * 60

    public struct Predicates: Sendable {
        public let canDelete: @Sendable (ChatMessage) -> Bool
        public let canEdit: @Sendable (ChatMessage) -> Bool
    }

    public static func build(
        currentIdentity: String?,
        messages: [ChatMessage],
        now: Date = Date()
    ) -> Predicates {
        guard let currentIdentity else {
            return Predicates(canDelete: { _ in false }, canEdit: { _ in false })
        }

        // Sids deletable by *some* viewer — the last-N of the whole
        // thread, minus structural messages.
        let deletableSids: Set<String> = {
            let recent = messages.suffix(recentEditableWindow)
            return Set(recent.compactMap { $0.attributes?.isStructural == true ? nil : $0.sid })
        }()

        // Sids editable by the viewer — the viewer's last-N own
        // messages, minus structural ones. Walking from the end so
        // the most recent N qualify.
        let editableSids: Set<String> = {
            var collected: [String] = []
            for message in messages.reversed() {
                if collected.count >= recentEditableWindow { break }
                if message.author != currentIdentity { continue }
                if message.attributes?.isStructural == true { continue }
                collected.append(message.sid)
            }
            return Set(collected)
        }()

        let isWithinWindow: @Sendable (ChatMessage) -> Bool = { message in
            guard let dateCreated = message.dateCreated else { return false }
            return now.timeIntervalSince(dateCreated) <= editDeleteWindowSeconds
        }

        let sameSide: @Sendable (String) -> Bool = { author in
            if currentIdentity.hasPrefix("uid:") {
                return author.hasPrefix("uid:")
            }
            return author == currentIdentity
        }

        return Predicates(
            canDelete: { message in
                guard deletableSids.contains(message.sid) else { return false }
                guard isWithinWindow(message) else { return false }
                return sameSide(message.author)
            },
            canEdit: { message in
                guard editableSids.contains(message.sid) else { return false }
                guard isWithinWindow(message) else { return false }
                return message.author == currentIdentity
            }
        )
    }
}
