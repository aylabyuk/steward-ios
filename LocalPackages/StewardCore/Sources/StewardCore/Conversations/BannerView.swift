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
        now: Date = Date()
    ) -> Result {
        let status = speaker.status ?? "planned"
        let response = invitation.response

        if status == "confirmed" {
            return Result(
                message: "Speaker has accepted the assignment",
                tone: .success,
                showApply: false
            )
        }
        if status == "declined" {
            return Result(
                message: "Speaker declined the invitation",
                tone: .destructive,
                showApply: false
            )
        }
        if let response, response.answer == "yes", response.acknowledgedAt == nil {
            return Result(
                message: "Speaker has accepted the assignment, but you need to confirm first.",
                tone: .pending,
                showApply: true,
                applyLabel: "Confirm"
            )
        }
        if let response, response.answer == "no", response.acknowledgedAt == nil {
            return Result(
                message: "Speaker has declined. Acknowledge to update the schedule.",
                tone: .destructive,
                showApply: true,
                applyLabel: "Acknowledge"
            )
        }
        if isExpired(invitation.expiresAt, now: now) {
            return Result(
                message: "Invitation expired before the speaker replied.",
                tone: .neutral,
                showApply: false
            )
        }
        if status == "invited" {
            return Result(
                message: "Waiting for speaker's reply.",
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

    /// Compose the "INVITED BY ORIEL ABSIN · APR 28" sub-line under
    /// the status pills. Returns nil for incomplete or unparseable
    /// inputs so the banner can hide the row entirely (no half-baked
    /// "INVITED BY · " strings).
    public static func invitedByLabel(
        inviterName: String?,
        createdAt: String?,
        locale: Locale = .current
    ) -> String? {
        guard let inviterName, inviterName.isEmpty == false else { return nil }
        guard let date = parseISO8601(createdAt) else { return nil }
        var style = Date.FormatStyle().month(.abbreviated).day().locale(locale)
        style.timeZone = .current
        let dateLabel = date.formatted(style)
        return "INVITED BY \(inviterName) · \(dateLabel)".uppercased()
    }

    /// Format `speakerLastSeenAt` as a human-readable label. Mirrors
    /// `formatLastSeen` at lines 103-118 of the web's
    /// `invitationBannerView.ts`. Returns `nil` for missing or
    /// unparseable timestamps so callers can hide the row.
    public static func formatLastSeen(
        _ iso8601: String?,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String? {
        guard let iso8601, let seenAt = parseISO8601(iso8601) else { return nil }
        let ageSeconds = now.timeIntervalSince(seenAt)
        if ageSeconds < 2 * 60 {
            return "Speaker is viewing the chat now"
        }
        if ageSeconds < 60 * 60 {
            let mins = Int(ageSeconds.rounded() / 60)
            return "Speaker last seen · \(mins) min ago"
        }
        var calendar = Calendar.current
        calendar.timeZone = .current
        let sameDay = calendar.isDate(seenAt, inSameDayAs: now)
        if sameDay {
            var style = Date.FormatStyle().hour().minute().locale(locale)
            style.timeZone = calendar.timeZone
            return "Speaker last seen · \(seenAt.formatted(style))"
        }
        var style = Date.FormatStyle().month(.abbreviated).day().locale(locale)
        style.timeZone = calendar.timeZone
        return "Speaker last seen · \(seenAt.formatted(style))"
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
