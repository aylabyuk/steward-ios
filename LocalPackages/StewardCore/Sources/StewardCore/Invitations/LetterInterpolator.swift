import Foundation

/// Pure port of the web's interpolate() helper at
/// `src/features/templates/utils/interpolate.ts:10-14`. The variable
/// map matches `prepareInvitationVars.ts` exactly so a letter
/// previewed on iOS reads the same as one a speaker eventually
/// receives via the web-side `sendSpeakerInvitation` callable.
public enum LetterInterpolator {

    /// Replace every `{{ token }}` (whitespace inside the braces is
    /// tolerated) with the matching value. Tokens with no entry in
    /// `vars` are left as-is so authors and previewers can see what's
    /// missing — same fallback the web takes.
    public static func interpolate(_ template: String, vars: [String: String]) -> String {
        guard template.isEmpty == false else { return "" }
        // Matches `{{<spaces?>identifier<spaces?>}}` — same shape as
        // the web's `\{\{\s*(\w+)\s*\}\}`.
        let pattern = #"\{\{\s*(\w+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }
        let nsString = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: nsString.length))
        guard matches.isEmpty == false else { return template }

        var result = ""
        var cursor = 0
        for match in matches {
            let fullRange = match.range
            let nameRange = match.range(at: 1)
            // Preserve everything between the previous match and this one.
            if fullRange.location > cursor {
                result += nsString.substring(with: NSRange(location: cursor, length: fullRange.location - cursor))
            }
            let key = nsString.substring(with: nameRange)
            if let value = vars[key] {
                result += value
            } else {
                // Unknown key — leave the original `{{ key }}` in place.
                result += nsString.substring(with: fullRange)
            }
            cursor = fullRange.location + fullRange.length
        }
        if cursor < nsString.length {
            result += nsString.substring(with: NSRange(location: cursor, length: nsString.length - cursor))
        }
        return result
    }

    /// Build the variable map a draft expands to. Mirrors
    /// `prepareInvitationVars.ts` — same key names, same default copy
    /// for an empty topic ("a topic of your choosing").
    public static func variables(
        for draft: InvitationDraft,
        today: Date,
        locale: Locale = .current
    ) -> [String: String] {
        var vars: [String: String] = [
            "wardName": draft.wardName,
            "inviterName": draft.inviterName,
            "today": longDate(today, locale: locale),
            "date": fullSundayDate(draft.meetingDate, locale: locale),
        ]

        // Speaker name aliases — both keys bind so a single template
        // can serve speaker and prayer letters alike, matching the
        // web's `prepareInvitationVars.ts` behaviour.
        vars["speakerName"] = draft.name
        if draft.kind.isPrayer {
            vars["prayerGiverName"] = draft.name
        }

        if let prayerType = draft.kind.prayerType {
            vars["prayerType"] = prayerType
        }

        if draft.kind == .speaker {
            let trimmed = draft.topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            vars["topic"] = trimmed.isEmpty ? "a topic of your choosing" : trimmed
        }

        return vars
    }

    /// "Sunday, May 17, 2026" — matches the web's
    /// `formatAssignedDate`. Civil-date parsing pinned to UTC so a
    /// Firestore meeting id like `"2026-05-17"` reads as May 17
    /// regardless of the device timezone.
    private static func fullSundayDate(_ isoDate: String, locale: Locale) -> String {
        let strategy = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        guard let date = try? Date(isoDate, strategy: strategy) else {
            return isoDate
        }
        var style = Date.FormatStyle()
            .weekday(.wide)
            .month(.wide)
            .day()
            .year()
            .locale(locale)
        style.timeZone = .gmt
        return date.formatted(style)
    }

    /// "April 21, 2026" — matches the web's `formatToday`.
    private static func longDate(_ date: Date, locale: Locale) -> String {
        var style = Date.FormatStyle()
            .month(.wide)
            .day()
            .year()
            .locale(locale)
        style.timeZone = .gmt
        return date.formatted(style)
    }
}
