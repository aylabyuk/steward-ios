import Testing
@testable import StewardCore

@Suite("CurrentWard — which ward the schedule scope points at")
@MainActor
struct CurrentWardTests {

    @Test("Starts unset")
    func startsNil() {
        let cw = CurrentWard()
        #expect(cw.wardId == nil)
    }

    @Test("`.single` member resolves to that member's wardId")
    func resolvesSingle() {
        let cw = CurrentWard()
        let m = MemberAccess(wardId: "stv1", uid: "u", role: nil, displayName: nil)
        cw.resolve(from: .single(m))
        #expect(cw.wardId == "stv1")
    }

    @Test("`.none` clears the ward — sign-out path tears down listeners cleanly")
    func resolvesNoneClears() {
        let cw = CurrentWard()
        cw.choose("stv1")
        cw.resolve(from: .none)
        #expect(cw.wardId == nil)
    }

    @Test(
        "`.checking` and `.multiple` leave wardId untouched — the picker is the user's job",
        arguments: [
            WardAccess.checking,
            WardAccess.multiple([MemberAccess(wardId: "a", uid: "u", role: nil, displayName: nil)])
        ]
    )
    func indeterminateStatesLeaveItAlone(state: WardAccess) {
        let cw = CurrentWard()
        cw.choose("preserved")
        cw.resolve(from: state)
        #expect(cw.wardId == "preserved")
    }

    @Test("`choose(_:)` overrides — drives the WardPicker selection flow")
    func chooseOverrides() {
        let cw = CurrentWard()
        cw.choose("stv1")
        #expect(cw.wardId == "stv1")
        cw.choose("stv2")
        #expect(cw.wardId == "stv2")
    }

    @Test("`clear()` resets — used by AuthClient.signOut to teardown the schedule scope")
    func clearResets() {
        let cw = CurrentWard()
        cw.choose("stv1")
        cw.clear()
        #expect(cw.wardId == nil)
    }
}
