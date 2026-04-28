import Foundation

/// Builds the "in 5 days" / "2 weeks ago" / "Today" microcopy that sits
/// next to a meeting's date headline on the schedule card. Mirrors the
/// web's MobileSundayBlock relative-time pill.
///
/// The function is pure — it takes an explicit `today` so tests stay
/// deterministic across machines, time zones, and run-times. Production
/// callers pass `Date()` and rely on the device's calendar/locale.
public enum RelativeDayLabel {

    /// Returns the natural-cased relative-time string ("In 5 days",
    /// "Today", "2 weeks ago") for a meeting whose ID is the
    /// `YYYY-MM-DD` civil date. Returns `nil` when the input can't be
    /// parsed — the UI omits the pill in that case rather than rendering
    /// a misleading fallback.
    ///
    /// The UI is responsible for casing/tracking ("IN 5 DAYS" matches the
    /// design's mono eyebrow style). Keeping this layer natural-cased
    /// means tests stay readable and the helper is reusable in other
    /// contexts (e.g. announcements).
    public static func string(
        fromISO8601 raw: String,
        today: Date,
        locale: Locale = .current
    ) -> String? {
        guard let target = parseCivilDate(raw) else { return nil }
        let calendar = utcCalendar(locale: locale)
        let normalizedToday = calendar.startOfDay(for: today)
        guard let days = calendar.dateComponents([.day], from: normalizedToday, to: target).day else {
            return nil
        }
        return phrase(forDays: days)
    }

    private static func phrase(forDays days: Int) -> String {
        switch days {
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        case -1:   return "Yesterday"
        case 2...6:
            return "In \(days) days"
        case -6 ... -2:
            return "\(-days) days ago"
        case 7...59:
            let weeks = days / 7
            return weeks == 1 ? "In 1 week" : "In \(weeks) weeks"
        case -59 ... -7:
            let weeks = (-days) / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        default:
            let months = days / 30
            if months >= 1 {
                return months == 1 ? "In 1 month" : "In \(months) months"
            } else {
                let mAbs = (-days) / 30
                return mAbs == 1 ? "1 month ago" : "\(mAbs) months ago"
            }
        }
    }

    private static func parseCivilDate(_ raw: String) -> Date? {
        let strategy = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        return try? Date(raw, strategy: strategy)
    }

    private static func utcCalendar(locale: Locale) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        cal.locale = locale
        return cal
    }
}
