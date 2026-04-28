import Testing
import StewardCore

@Suite("SubscriptionPath.key — segment readiness")
struct SubscriptionPathTests {

    @Test("All non-empty segments → joined with /")
    func allNonEmpty() {
        #expect(SubscriptionPath.key(["wards", "stv1", "meetings"]) == "wards/stv1/meetings")
    }

    @Test("Empty segment array → nil (nothing to subscribe to)")
    func emptyArray() {
        #expect(SubscriptionPath.key([]) == nil)
    }

    @Test("Any nil segment → nil")
    func anyNil() {
        #expect(SubscriptionPath.key(["wards", nil, "meetings"]) == nil)
    }

    @Test("Any empty-string segment → nil")
    func anyEmpty() {
        #expect(SubscriptionPath.key(["wards", "", "meetings"]) == nil)
    }

    @Test("Trailing nil → nil (covers wardId-not-yet-hydrated race)")
    func trailingNil() {
        #expect(SubscriptionPath.key(["wards", "stv1", "members", nil]) == nil)
    }

    @Test("Single segment, non-empty → that segment")
    func singleSegment() {
        #expect(SubscriptionPath.key(["wards"]) == "wards")
    }
}
