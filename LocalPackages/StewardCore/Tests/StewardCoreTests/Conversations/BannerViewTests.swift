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

@Suite("BannerView.invitedByLabel — 'INVITED BY ORIEL ABSIN · APR 28'")
struct InvitedByLabelTests {

    private func iso(month: Int, day: Int) -> String {
        // Pin to noon UTC so timezone shifts don't move the day.
        String(format: "2026-%02d-%02dT12:00:00Z", month, day)
    }

    @Test("Renders inviter name + abbreviated short date")
    func happyPath() {
        let label = BannerView.invitedByLabel(
            inviterName: "Oriel Absin",
            createdAt: iso(month: 4, day: 28)
        )
        #expect(label?.contains("ORIEL ABSIN") == true)
        #expect(label?.contains("APR 28") == true)
    }

    @Test("Missing inviter name returns nil — banner hides the row")
    func missingInviterName() {
        #expect(BannerView.invitedByLabel(inviterName: nil, createdAt: iso(month: 4, day: 28)) == nil)
    }

    @Test("Missing date returns nil — incomplete data hides the row")
    func missingDate() {
        #expect(BannerView.invitedByLabel(inviterName: "Oriel", createdAt: nil) == nil)
    }

    @Test("Malformed date returns nil rather than rendering a junk label")
    func malformedDate() {
        #expect(BannerView.invitedByLabel(inviterName: "Oriel", createdAt: "not-a-date") == nil)
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
