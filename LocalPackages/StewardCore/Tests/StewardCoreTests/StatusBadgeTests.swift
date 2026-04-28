import Testing
@testable import StewardCore

@Suite("StatusBadge.Tone — string status → tone mapping")
struct StatusBadgeToneTests {

    @Test("Speaker / prayer statuses map directly")
    func speakerStatuses() {
        #expect(StatusBadge.Tone(rawStatus: "planned") == .neutral)
        #expect(StatusBadge.Tone(rawStatus: "invited") == .pending)
        #expect(StatusBadge.Tone(rawStatus: "confirmed") == .success)
        #expect(StatusBadge.Tone(rawStatus: "declined") == .destructive)
    }

    @Test("Meeting statuses fold into the same four tone slots")
    func meetingStatuses() {
        #expect(StatusBadge.Tone(rawStatus: "draft") == .neutral)
        #expect(StatusBadge.Tone(rawStatus: "pending_approval") == .pending)
        #expect(StatusBadge.Tone(rawStatus: "approved") == .success)
        #expect(StatusBadge.Tone(rawStatus: "published") == .success)
    }

    @Test("Unknown / nil statuses fall back to .neutral so the UI still renders")
    func unknownFallsBack() {
        #expect(StatusBadge.Tone(rawStatus: nil) == .neutral)
        #expect(StatusBadge.Tone(rawStatus: "") == .neutral)
        #expect(StatusBadge.Tone(rawStatus: "future-status-we-dont-know") == .neutral)
    }

    @Test("Match is case-insensitive — backend may emit canonical or upper-case")
    func caseInsensitive() {
        #expect(StatusBadge.Tone(rawStatus: "CONFIRMED") == .success)
        #expect(StatusBadge.Tone(rawStatus: "Pending_Approval") == .pending)
    }
}
