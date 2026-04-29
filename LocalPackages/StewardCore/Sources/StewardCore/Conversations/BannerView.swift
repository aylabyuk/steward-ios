import Foundation

/// Pure port of the web's `deriveBannerView` + `formatLastSeen`
/// helpers at `src/features/invitations/utils/invitationBannerView.ts`.
/// Drives the message + colour scheme rendered above the chat thread,
/// plus the speaker heartbeat label below it.
public enum BannerView {

    /// Tone the banner card paints itself with. Maps to the design
    /// system's existing 4-tone palette (`StatusBadge.Tone` shares
    /// the same vocabulary so the banner can match the schedule
    /// row's status dot).
    public enum Tone: Sendable, Equatable {
        case success     // green — speaker accepted
        case pending     // brass/warning — waiting / pre-apply
        case destructive // bordeaux — declined or pre-apply on no
        case neutral     // parchment — planned or expired
    }

    public struct Result: Sendable, Equatable {
        public let message: String
        public let tone: Tone
        public let showApply: Bool
        /// Label for the bordeaux Apply button (only set when
        /// `showApply` is true). The web uses two distinct copies for
        /// Yes vs No — keep parity so the bishop knows which path
        /// they're acknowledging.
        public let applyLabel: String?

        public init(message: String, tone: Tone, showApply: Bool, applyLabel: String? = nil) {
            self.message = message
            self.tone = tone
            self.showApply = showApply
            self.applyLabel = applyLabel
        }
    }

    /// Compose the banner state for a given speaker / invitation pair.
    /// Priority order matches the web (`invitationBannerView.ts:22-88`):
    ///   1. Final speaker statuses (confirmed / declined) win — once
    ///      the bishopric marks a status, it's the source of truth.
    ///   2. Unacknowledged response (speaker replied, bishop hasn't
    ///      hit Apply) surfaces the Apply CTA.
    ///   3. Expired invitations with no response read as "expired".
    ///   4. Otherwise: "waiting for reply" (invited) or "not yet sent"
    ///      (planned / unknown).
    public static func derive(
        speaker: Speaker,
        invitation: SpeakerInvitation,
        kind: SlotKind = .speaker,
        now: Date = Date()
    ) -> Result {
        let status = speaker.status ?? "planned"
        let response = invitation.response
        let noun = kind.assigneeNoun.capitalizedFirst

        if status == "confirmed" {
            return Result(
                message: "\(noun) has accepted the assignment",
                tone: .success,
                showApply: false
            )
        }
        if status == "declined" {
            return Result(
                message: "\(noun) declined the invitation",
                tone: .destructive,
                showApply: false
            )
        }
        if let response, response.answer == "yes", response.acknowledgedAt == nil {
            return Result(
                message: "\(noun) has accepted the assignment, but you need to confirm first.",
                tone: .pending,
                showApply: true,
                applyLabel: "Confirm"
            )
        }
        if let response, response.answer == "no", response.acknowledgedAt == nil {
            return Result(
                message: "\(noun) has declined. Acknowledge to update the schedule.",
                tone: .destructive,
                showApply: true,
                applyLabel: "Acknowledge"
            )
        }
        if isExpired(invitation.expiresAt, now: now) {
            return Result(
                message: "Invitation expired before the \(kind.assigneeNoun) replied.",
                tone: .neutral,
                showApply: false
            )
        }
        if status == "invited" {
            return Result(
                message: "Waiting for \(kind.assigneeNoun)'s reply.",
                tone: .pending,
                showApply: false
            )
        }
        return Result(
            message: "Planned — invitation not yet sent.",
            tone: .neutral,
            showApply: false
        )
    }

    /// Compose the status-provenance sub-line under the pills:
    /// `"INVITED BY ORIEL ABSIN · APR 28"`,
    /// `"SET MANUALLY BY ORIEL ABSIN · APR 28"`,
    /// `"FROM REPLY · APPLIED BY ORIEL ABSIN · APR 28"`.
    /// Pure port of the web's `statusProvenanceLabel` at
    /// `src/features/schedule/utils/statusProvenance.ts:32-45`. Returns
    /// nil only when the speaker doc is missing `statusSource` (legacy
    /// pre-rollout rows) so the banner can hide the line entirely.
    public static func statusProvenanceLabel(
        speaker: Speaker,
        membersByUid: [String: String],
        locale: Locale = .current
    ) -> String? {
        guard let source = speaker.statusSource else { return nil }
        let actorUid = speaker.statusSetBy
        let actorName: String? = {
            guard let actorUid else { return nil }
            // The web stamps `uid:{firebaseUid}` on Twilio identities
            // but raw `{firebaseUid}` on the Firestore doc. Lookup
            // tolerates both — the chat sheet's `membersByUid` map is
            // keyed on `uid:{...}` per the Twilio identity scheme.
            return membersByUid[actorUid]
                ?? membersByUid["uid:\(actorUid)"]
                ?? (actorUid.hasPrefix("uid:") ? membersByUid[actorUid] : nil)
        }()
        let verb = statusVerb(status: speaker.status ?? "planned", source: source)
        let dateSuffix: String? = {
            guard let date = parseISO8601(speaker.statusSetAt) else { return nil }
            var style = Date.FormatStyle().month(.abbreviated).day().locale(locale)
            style.timeZone = .current
            return date.formatted(style)
        }()
        var pieces: [String] = []
        if source == "speaker-response" {
            pieces.append(verb)
            if let actorName {
                pieces.append("· APPLIED BY \(actorName.uppercased())")
            } else {
                pieces.append("· APPLIED")
            }
        } else {
            pieces.append(verb)
            if let actorName {
                pieces.append("BY \(actorName.uppercased())")
            }
        }
        if let dateSuffix {
            pieces.append("· \(dateSuffix.uppercased())")
        }
        return pieces.joined(separator: " ")
    }

    private static func statusVerb(status: String, source: String) -> String {
        if source == "speaker-response" { return "FROM REPLY" }
        switch status {
        case "planned":   return "PLANNED"
        case "invited":   return "INVITED"
        case "confirmed", "declined": return "SET MANUALLY"
        default:           return status.uppercased()
        }
    }

    /// Format `speakerLastSeenAt` as a human-readable label. Mirrors
    /// `formatLastSeen` at lines 103-118 of the web's
    /// `invitationBannerView.ts`. Returns `nil` for missing or
    /// unparseable timestamps so callers can hide the row.
    public static func formatLastSeen(
        _ iso8601: String?,
        kind: SlotKind = .speaker,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String? {
        guard let iso8601, let seenAt = parseISO8601(iso8601) else { return nil }
        let noun = kind.assigneeNoun.capitalizedFirst
        let ageSeconds = now.timeIntervalSince(seenAt)
        if ageSeconds < 2 * 60 {
            return "\(noun) is viewing the chat now"
        }
        if ageSeconds < 60 * 60 {
            let mins = Int(ageSeconds.rounded() / 60)
            return "\(noun) last seen · \(mins) min ago"
        }
        var calendar = Calendar.current
        calendar.timeZone = .current
        let sameDay = calendar.isDate(seenAt, inSameDayAs: now)
        if sameDay {
            var style = Date.FormatStyle().hour().minute().locale(locale)
            style.timeZone = calendar.timeZone
            return "\(noun) last seen · \(seenAt.formatted(style))"
        }
        var style = Date.FormatStyle().month(.abbreviated).day().locale(locale)
        style.timeZone = calendar.timeZone
        return "\(noun) last seen · \(seenAt.formatted(style))"
    }

    private static func isExpired(_ iso8601: String?, now: Date) -> Bool {
        guard let date = parseISO8601(iso8601) else { return false }
        return date < now
    }

    private static func parseISO8601(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: raw) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

private extension String {
    /// Capitalize only the first character — `assigneeNoun` returns
    /// lowercase ("speaker" / "prayer giver") so it can slot into
    /// mid-sentence copy; sentence-leading uses need a single-letter
    /// uppercase. `String.capitalized` capitalizes every word and
    /// would turn "prayer giver" into "Prayer Giver" — wrong here.
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
