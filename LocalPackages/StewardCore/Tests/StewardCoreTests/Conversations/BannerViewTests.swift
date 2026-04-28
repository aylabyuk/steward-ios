import Foundation
import Testing
@testable import StewardCore

/// Pure port of the web's `deriveBannerView` + `formatLastSeen` at
/// `src/features/invitations/utils/invitationBannerView.ts`. The
/// banner copy is the most user-visible derivation in the chat
/// sheet — pin every branch.

@Suite("BannerView.derive — what message + tone the chat banner shows")
struct DeriveBannerViewTests {

    private func speaker(status: String?) -> Speaker {
        Speaker(name: "Sister Davis", status: status)
    }

    private func invitation(
        response: SpeakerInvitation.Response? = nil,
        expiresAt: String? = nil
    ) -> SpeakerInvitation {
        SpeakerInvitation(
            speakerRef: SpeakerInvitation.SpeakerRef(meetingDate: "2026-05-17", speakerId: "spk_1"),
            speakerName: "Sister Davis",
            expiresAt: expiresAt,
            response: response
        )
    }

    @Test("Confirmed status wins over everything — green tone, no apply button")
    func confirmedTakesPriority() {
        let view = BannerView.derive(
            speaker: speaker(status: "confirmed"),
            invitation: invitation(response: SpeakerInvitation.Response(answer: "yes"))
        )
        #expect(view.message.contains("accepted"))
        #expect(view.tone == .success)
        #expect(view.showApply == false)
    }

    @Test("Declined status wins over response — bordeaux tone")
    func declinedTakesPriority() {
        let view = BannerView.derive(
            speaker: speaker(status: "declined"),
            invitation: invitation(response: SpeakerInvitation.Response(answer: "no"))
        )
        #expect(view.message.contains("declined"))
        #expect(view.tone == .destructive)
        #expect(view.showApply == false)
    }

    @Test("Speaker said yes but bishop hasn't acknowledged → warning + Confirm CTA")
    func unacknowledgedYes() {
        let view = BannerView.derive(
            speaker: speaker(status: "invited"),
            invitation: invitation(response: SpeakerInvitation.Response(answer: "yes"))
        )
        #expect(view.message.contains("accepted"))
        #expect(view.tone == .pending)
        #expect(view.showApply)
        #expect(view.applyLabel == "Confirm")
    }

    @Test("Speaker said no but bishop hasn't acknowledged → bordeaux + Acknowledge CTA")
    func unacknowledgedNo() {
        let view = BannerView.derive(
            speaker: speaker(status: "invited"),
            invitation: invitation(response: SpeakerInvitation.Response(answer: "no"))
        )
        #expect(view.message.contains("declined"))
        #expect(view.tone == .destructive)
        #expect(view.showApply)
        #expect(view.applyLabel == "Acknowledge")
    }

    @Test("Acknowledged response no longer shows the Apply CTA")
    func acknowledgedHidesApply() {
        let view = BannerView.derive(
            speaker: speaker(status: "invited"),
            invitation: invitation(response: SpeakerInvitation.Response(
                answer: "yes",
                acknowledgedAt: "2026-04-28T00:00:00Z"
            ))
        )
        #expect(view.showApply == false)
    }

    @Test("Expired invitation with no response surfaces 'expired' message")
    func expiredNoResponse() {
        let pastIso = "2025-01-01T00:00:00Z"
        let view = BannerView.derive(
            speaker: speaker(status: "invited"),
            invitation: invitation(expiresAt: pastIso)
        )
        #expect(view.message.contains("expired"))
        #expect(view.tone == .neutral)
    }

    @Test("Status invited with no response and not expired → 'waiting for reply'")
    func waitingForReply() {
        let view = BannerView.derive(
            speaker: speaker(status: "invited"),
            invitation: invitation()
        )
        #expect(view.message.contains("Waiting for speaker"))
        #expect(view.tone == .pending)
    }

    @Test("Status planned (or nil) → 'invitation not yet sent'")
    func plannedFallback() {
        let view = BannerView.derive(
            speaker: speaker(status: "planned"),
            invitation: invitation()
        )
        #expect(view.message.contains("not yet sent"))
        #expect(view.tone == .neutral)

        let viewNil = BannerView.derive(
            speaker: speaker(status: nil),
            invitation: invitation()
        )
        #expect(viewNil.tone == .neutral)
    }
}

@Suite("BannerView.statusProvenanceLabel — 'SET MANUALLY BY ORIEL ABSIN · APR 28'")
struct StatusProvenanceLabelTests {

    private func iso(month: Int, day: Int) -> String {
        String(format: "2026-%02d-%02dT12:00:00Z", month, day)
    }

    private func speaker(
        status: String?,
        source: String?,
        setBy: String? = "uid:bishop",
        setAt: String? = "2026-04-28T12:00:00Z"
    ) -> Speaker {
        Speaker(
            name: "Sister Davis",
            status: status,
            statusSource: source,
            statusSetBy: setBy,
            statusSetAt: setAt
        )
    }

    @Test("Manual invited → 'INVITED BY {name} · {date}'")
    func manualInvited() {
        let label = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "invited", source: "manual"),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(label?.contains("INVITED BY ORIEL ABSIN") == true)
        #expect(label?.contains("APR 28") == true)
    }

    @Test("Manual confirmed/declined → 'SET MANUALLY BY {name} · {date}' (not 'CONFIRMED BY')")
    func manualTerminal() {
        // Mirrors the web's verb mapping at statusProvenance.ts:47-62 —
        // confirmed/declined manual writes both render as "set manually"
        // because the action is the bishopric override, not the
        // speaker's response.
        let confirmed = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "confirmed", source: "manual"),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(confirmed?.contains("SET MANUALLY") == true)

        let declined = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "declined", source: "manual"),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(declined?.contains("SET MANUALLY") == true)
    }

    @Test("Speaker-response → 'FROM REPLY · APPLIED BY {name} · {date}'")
    func speakerResponseApplied() {
        let label = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "confirmed", source: "speaker-response"),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(label?.contains("FROM REPLY") == true)
        #expect(label?.contains("APPLIED BY ORIEL ABSIN") == true)
    }

    @Test("Unknown setBy uid renders without the 'BY {name}' suffix")
    func unknownActor() {
        let label = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "invited", source: "manual", setBy: "uid:stranger"),
            membersByUid: [:] // no member resolved
        )
        #expect(label?.contains("INVITED") == true)
        #expect(label?.contains("BY ") == false || label?.contains("BY APR") == true)
    }

    @Test("Missing statusSource returns nil — pre-rollout docs hide the line")
    func missingSource() {
        let label = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "invited", source: nil),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(label == nil)
    }

    @Test("Missing statusSetAt still renders — date suffix just gets dropped")
    func missingDate() {
        let label = BannerView.statusProvenanceLabel(
            speaker: speaker(status: "invited", source: "manual", setAt: nil),
            membersByUid: ["uid:bishop": "Oriel Absin"]
        )
        #expect(label?.contains("INVITED BY ORIEL ABSIN") == true)
        #expect(label?.contains("APR 28") == false)
    }
}

@Suite("BannerView.formatLastSeen — speaker heartbeat label")
struct FormatLastSeenTests {

    private var now: Date { Date(timeIntervalSince1970: 1_745_000_000) }

    private func iso(secondsAgo: Int) -> String {
        let date = now.addingTimeInterval(-Double(secondsAgo))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    @Test("Within 2 minutes reads as 'viewing now'")
    func live() {
        let label = BannerView.formatLastSeen(iso(secondsAgo: 30), now: now)
        #expect(label?.lowercased().contains("now") == true)
    }

    @Test("Between 2 and 60 minutes reads as 'N min ago'")
    func minutesAgo() {
        let label = BannerView.formatLastSeen(iso(secondsAgo: 5 * 60), now: now)
        #expect(label?.contains("5 min ago") == true)
    }

    @Test("Nil last-seen returns nil — banner just hides the row")
    func nilSeenHides() {
        #expect(BannerView.formatLastSeen(nil, now: now) == nil)
    }

    @Test("Malformed timestamp returns nil rather than throwing")
    func malformedTimestampReturnsNil() {
        #expect(BannerView.formatLastSeen("not-a-date", now: now) == nil)
    }
}
