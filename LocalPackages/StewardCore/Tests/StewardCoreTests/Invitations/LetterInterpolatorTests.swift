import Foundation
import Testing
@testable import StewardCore

/// Pure port of the web's interpolate() helper at
/// src/features/templates/utils/interpolate.ts:10-14. The variable map
/// matches prepareInvitationVars.ts so an iOS-rendered preview matches
/// what a speaker eventually receives.

private let fixedToday = ISO8601DateFormatter().date(from: "2026-04-21T12:00:00Z")!

private let posix = Locale(identifier: "en_US_POSIX")

private func speakerDraft(topic: String? = "Faith") -> InvitationDraft {
    InvitationDraft(
        kind: .speaker,
        wardId: "stv1",
        meetingDate: "2026-05-17",
        wardName: "Eglinton Ward",
        inviterName: "Bishop Smith",
        name: "Sarah Bensen",
        email: nil,
        phone: nil,
        topic: topic,
        role: .member
    )
}

private func prayerDraft(kind: SlotKind = .openingPrayer) -> InvitationDraft {
    InvitationDraft(
        kind: kind,
        wardId: "stv1",
        meetingDate: "2026-05-17",
        wardName: "Eglinton Ward",
        inviterName: "Bishop Smith",
        name: "Brother Cole",
        email: nil,
        phone: nil,
        topic: nil,
        role: nil
    )
}

@Suite("LetterInterpolator.interpolate — the {{token}} substitution rule")
struct LetterInterpolatorReplaceTests {

    @Test("A single token resolves")
    func singleToken() {
        let out = LetterInterpolator.interpolate("Hello {{name}}", vars: ["name": "Sarah"])
        #expect(out == "Hello Sarah")
    }

    @Test("A repeated token resolves every occurrence")
    func repeatedToken() {
        let out = LetterInterpolator.interpolate(
            "{{name}} — {{name}} again",
            vars: ["name": "Sarah"]
        )
        #expect(out == "Sarah — Sarah again")
    }

    @Test("Unknown tokens are left as-is so authors see what's missing")
    func unknownLeftAlone() {
        let out = LetterInterpolator.interpolate("{{a}} / {{b}}", vars: ["a": "1"])
        #expect(out == "1 / {{b}}")
    }

    @Test(
        "Whitespace inside the braces is tolerated",
        arguments: [
            "{{ name }}",
            "{{name }}",
            "{{ name}}",
            "{{\tname\t}}",
        ]
    )
    func whitespaceTolerant(template: String) {
        let out = LetterInterpolator.interpolate(template, vars: ["name": "Sarah"])
        #expect(out == "Sarah")
    }

    @Test("Empty template returns empty string")
    func empty() {
        #expect(LetterInterpolator.interpolate("", vars: ["a": "1"]) == "")
    }

    @Test("Templates with no tokens pass through unchanged")
    func noTokens() {
        #expect(LetterInterpolator.interpolate("Plain text", vars: [:]) == "Plain text")
    }
}

@Suite("LetterInterpolator.variables — the variable map a speaker draft expands to")
struct LetterInterpolatorSpeakerVariablesTests {

    @Test("Speaker name binds to {{speakerName}}")
    func speakerName() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["speakerName"] == "Sarah Bensen")
    }

    @Test("Speaker topic binds to {{topic}} when provided")
    func topicProvided() {
        let vars = LetterInterpolator.variables(for: speakerDraft(topic: "Faith"), today: fixedToday, locale: posix)
        #expect(vars["topic"] == "Faith")
    }

    @Test("Empty topic substitutes the web's 'a topic of your choosing' default")
    func topicEmpty() {
        let vars = LetterInterpolator.variables(for: speakerDraft(topic: nil), today: fixedToday, locale: posix)
        #expect(vars["topic"] == "a topic of your choosing")
    }

    @Test("Whitespace-only topic also substitutes the default")
    func topicWhitespace() {
        let vars = LetterInterpolator.variables(for: speakerDraft(topic: "   "), today: fixedToday, locale: posix)
        #expect(vars["topic"] == "a topic of your choosing")
    }

    @Test("Ward name binds to {{wardName}}")
    func wardName() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["wardName"] == "Eglinton Ward")
    }

    @Test("Inviter name binds to {{inviterName}}")
    func inviter() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["inviterName"] == "Bishop Smith")
    }

    @Test("{{date}} reads the meetingDate as the assigned Sunday, formatted")
    func date() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["date"] == "Sunday, May 17, 2026")
    }

    @Test("{{today}} reads the passed-in today date, formatted")
    func today() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["today"] == "April 21, 2026")
    }

    @Test("Speaker drafts have no {{prayerType}}")
    func noPrayerType() {
        let vars = LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        #expect(vars["prayerType"] == nil)
    }
}

@Suite("LetterInterpolator.variables — what a prayer draft binds")
struct LetterInterpolatorPrayerVariablesTests {

    @Test("Opening prayer drafts expose 'Opening Prayer' as {{prayerType}}")
    func opening() {
        let vars = LetterInterpolator.variables(for: prayerDraft(kind: .openingPrayer), today: fixedToday, locale: posix)
        #expect(vars["prayerType"] == "Opening Prayer")
    }

    @Test("Benediction drafts expose 'Benediction' as {{prayerType}}")
    func benediction() {
        let vars = LetterInterpolator.variables(for: prayerDraft(kind: .benediction), today: fixedToday, locale: posix)
        #expect(vars["prayerType"] == "Benediction")
    }

    @Test("Prayer assignee name also binds to {{prayerGiverName}} (web parity)")
    func prayerGiverName() {
        let vars = LetterInterpolator.variables(for: prayerDraft(), today: fixedToday, locale: posix)
        #expect(vars["prayerGiverName"] == "Brother Cole")
    }

    @Test("{{speakerName}} also binds for prayers — web's templates are sometimes shared")
    func prayerSpeakerNameAlias() {
        let vars = LetterInterpolator.variables(for: prayerDraft(), today: fixedToday, locale: posix)
        #expect(vars["speakerName"] == "Brother Cole")
    }

    @Test("Prayer drafts have no {{topic}} variable")
    func noTopic() {
        let vars = LetterInterpolator.variables(for: prayerDraft(), today: fixedToday, locale: posix)
        #expect(vars["topic"] == nil)
    }
}

@Suite("LetterInterpolator end-to-end — the rendered letter the bishopric reads")
struct LetterInterpolatorRenderTests {

    @Test("A whole speaker letter with mixed tokens renders cleanly")
    func speakerLetter() {
        let body = "Dear {{speakerName}},\n\nWe'd love you to speak on {{topic}} on {{date}} in {{wardName}}.\n\nWarmly,\n{{inviterName}}"
        let out = LetterInterpolator.interpolate(
            body,
            vars: LetterInterpolator.variables(for: speakerDraft(), today: fixedToday, locale: posix)
        )
        #expect(out.contains("Dear Sarah Bensen"))
        #expect(out.contains("speak on Faith"))
        #expect(out.contains("on Sunday, May 17, 2026"))
        #expect(out.contains("in Eglinton Ward"))
        #expect(out.contains("Warmly,\nBishop Smith"))
    }

    @Test("A prayer letter renders {{prayerType}} resolved")
    func prayerLetter() {
        let body = "Dear {{prayerGiverName}}, would you offer the {{prayerType}} on {{date}}?"
        let out = LetterInterpolator.interpolate(
            body,
            vars: LetterInterpolator.variables(for: prayerDraft(), today: fixedToday, locale: posix)
        )
        #expect(out == "Dear Brother Cole, would you offer the Opening Prayer on Sunday, May 17, 2026?")
    }
}
