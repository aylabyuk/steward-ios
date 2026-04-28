import Foundation

/// Pure port of the web's `computeConfirmCopy` at
/// `src/features/schedule/utils/speakerStatusConfirmCopy.ts:55-74`.
/// Builds the title / body / button-label / danger-flag the
/// status-pill confirm dialog renders for a requested transition.
///
/// Two shapes:
///   * Rollback out of a terminal state (confirmed/declined →
///     planned/invited) → heavy-friction copy that names who set the
///     original commitment and what downstream surfaces lose.
///   * Forward transition (→ invited / confirmed / declined) → the
///     per-target base copy, optionally prefixed with a provenance
///     nudge when someone else set the current status.
public enum StatusConfirmCopy {

    public struct Result: Sendable, Equatable {
        public let title: String
        public let body: String
        public let confirmLabel: String
        public let danger: Bool
    }

    public static func compute(
        current: String,
        next: String,
        currentStatusSource: String?,
        currentStatusSetBy: String?,
        membersByUid: [String: String],
        currentUserUid: String?
    ) -> Result {
        if isTerminal(current) && !isTerminal(next) {
            return rollback(
                from: current,
                to: next,
                source: currentStatusSource,
                setBy: currentStatusSetBy,
                membersByUid: membersByUid,
                currentUserUid: currentUserUid
            )
        }
        let base = baseCopy(forward: next)
        let prefix = overridePrefix(
            source: currentStatusSource,
            setBy: currentStatusSetBy,
            membersByUid: membersByUid,
            currentUserUid: currentUserUid
        )
        let body = prefix.map { "\($0) \(base.body)" } ?? base.body
        return Result(
            title: base.title,
            body: body,
            confirmLabel: base.confirmLabel,
            danger: next == "declined"
        )
    }

    private struct BaseCopy: Sendable {
        let title: String
        let body: String
        let confirmLabel: String
    }

    private static func baseCopy(forward next: String) -> BaseCopy {
        switch next {
        case "invited":
            return BaseCopy(
                title: "Mark as Invited?",
                body: "Use this when you've already reached out through another channel — email, SMS, or a hallway conversation. You won't be able to send an in-app invitation for this speaker unless you switch them back to Planned.",
                confirmLabel: "Mark as Invited"
            )
        case "confirmed":
            return BaseCopy(
                title: "Mark as Confirmed?",
                body: "Use this once the speaker has accepted the invitation. You won't be able to send further invitations unless you switch them back to Planned.",
                confirmLabel: "Mark as Confirmed"
            )
        case "declined":
            return BaseCopy(
                title: "Mark as Declined?",
                body: "We'll keep the speaker on file until you add a replacement. You won't be able to send further invitations unless you switch them back to Planned.",
                confirmLabel: "Mark as Declined"
            )
        default:
            // "planned" forward — never reached by computeConfirmCopy
            // (the pills emit it only as a rollback target). Defensive
            // fallback so the dialog is never empty.
            return BaseCopy(
                title: "Switch to Planned?",
                body: "The speaker will return to the Planned state.",
                confirmLabel: "Switch to Planned"
            )
        }
    }

    private static func rollback(
        from current: String,
        to next: String,
        source: String?,
        setBy: String?,
        membersByUid: [String: String],
        currentUserUid: String?
    ) -> Result {
        let whoSet: String? = {
            if source == "speaker-response" { return "The speaker" }
            return authorshipHint(setBy: setBy, membersByUid: membersByUid, currentUserUid: currentUserUid)
        }()
        let verb = current == "confirmed" ? "confirmation" : "decline"
        let destLabel = next == "planned" ? "Planned" : "Invited"
        let toLine = next == "planned"
            ? "The card reverts to Planned and you can send a fresh invitation or remove them without further friction."
            : "The card reverts to Invited — the commitment log still carries the history but this speaker is no longer locked in."
        let subject = whoSet ?? "This"
        return Result(
            title: current == "confirmed" ? "Clear confirmed status?" : "Undo decline?",
            body: "\(subject) set the \(verb). Rolling back to \(destLabel) clears that commitment from the card. The history stays in the audit log, but downstream surfaces (chat banner, schedule pill) will stop reflecting it. \(toLine)",
            confirmLabel: current == "confirmed" ? "Clear confirmation" : "Undo decline",
            danger: true
        )
    }

    private static func authorshipHint(
        setBy: String?,
        membersByUid: [String: String],
        currentUserUid: String?
    ) -> String? {
        guard let setBy else { return nil }
        if setBy == currentUserUid { return "You" }
        return membersByUid[setBy]
    }

    private static func overridePrefix(
        source: String?,
        setBy: String?,
        membersByUid: [String: String],
        currentUserUid: String?
    ) -> String? {
        guard let source else { return nil }
        if source == "speaker-response" {
            return "The speaker set this status by replying to the invitation. Overriding it won't change their reply — it only updates the schedule record."
        }
        guard let setBy, setBy != currentUserUid else { return nil }
        guard let displayName = membersByUid[setBy] else { return nil }
        return "\(displayName) set the current status. Override with care — there's no automatic notification to them."
    }

    private static func isTerminal(_ status: String) -> Bool {
        status == "confirmed" || status == "declined"
    }
}
