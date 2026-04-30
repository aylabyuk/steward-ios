import Foundation

/// Generates the calendar of upcoming Sundays the schedule renders. Mirrors
/// the web's `upcomingSundays(from, weeks)` in `src/lib/dates.ts` — the
/// schedule is a *calendar* of Sunday slots (each one renders whether or
/// not a meeting doc exists), not a list of existing meeting docs.
///
/// Pure function so tests can pin a synthetic "today" without mocking.
public enum UpcomingSundays {

    /// Returns up to `weeks` consecutive Sunday `YYYY-MM-DD` strings,
    /// ascending from the next Sunday on or after `from`. If `from`
    /// itself is a Sunday, that same day is the first entry.
    public static func next(from: Date, weeks: Int) -> [String] {
        guard weeks > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        // Step forward to the next Sunday-on-or-after `from` in UTC, the
        // same civil-date semantics the rest of the schedule uses
        // (meeting doc IDs are civil dates, not timestamps).
        let weekday = calendar.component(.weekday, from: from)
        let daysToSunday = (8 - weekday) % 7
        guard let firstSunday = calendar.date(byAdding: .day, value: daysToSunday, to: from) else {
            return []
        }

        var out: [String] = []
        out.reserveCapacity(weeks)
        for i in 0..<weeks {
            guard let sunday = calendar.date(byAdding: .day, value: i * 7, to: firstSunday) else { continue }
            out.append(format(sunday, calendar: calendar))
        }
        return out
    }

    private static func format(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
