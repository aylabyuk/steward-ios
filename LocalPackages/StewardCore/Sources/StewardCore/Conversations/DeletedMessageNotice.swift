import Foundation

/// Body copy for the system notice posted in place of a deleted
/// message. iOS deviation from the web — the web silently removes
/// the bubble (`message.remove()` with no follow-up post), leaving
/// a gap in the speaker's timeline. iOS leaves a tombstone so the
/// speaker sees that *something* happened, who did it, and roughly
/// when. Pure copy generator — no Twilio / Firestore dependency, so
/// the audit string is pinnable in tests.
public enum DeletedMessageNotice {

    /// Compose the system notice body. `removedBy` is the bishop's
    /// display name (or nil if it isn't available — falls back to the
    /// actor-less form). `date` is rendered as "Mon DD" in the
    /// caller's timezone.
    public static func body(
        removedBy displayName: String?,
        on date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let datePart = formattedDate(date, locale: locale, timeZone: timeZone)
        if let trimmedName, trimmedName.isEmpty == false {
            return "Message removed by \(trimmedName) \u{00B7} \(datePart)."
        }
        return "Message removed \u{00B7} \(datePart)."
    }

    private static func formattedDate(
        _ date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var style = Date.FormatStyle()
            .month(.abbreviated)
            .day()
            .locale(locale)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
