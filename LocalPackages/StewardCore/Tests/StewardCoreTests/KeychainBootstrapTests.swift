import Foundation
import Testing
@testable import StewardCore

@Suite("KeychainBootstrap — first-launch wipe gating")
struct KeychainBootstrapTests {

    /// Fresh in-memory UserDefaults suite per test so the host's real
    /// defaults are never touched.
    private func freshDefaults() -> UserDefaults {
        let suite = "kbtest-\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @Test("On first launch — wipe runs and the flag is set")
    func firstLaunch() {
        let defaults = freshDefaults()
        var wipeCalls = 0

        KeychainBootstrap.clearIfFirstLaunch(defaults: defaults) {
            wipeCalls += 1
        }

        #expect(wipeCalls == 1)
        #expect(defaults.bool(forKey: KeychainBootstrap.firstLaunchKey))
    }

    @Test("On subsequent launch — wipe is skipped, flag stays set")
    func subsequentLaunch() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: KeychainBootstrap.firstLaunchKey)
        var wipeCalls = 0

        KeychainBootstrap.clearIfFirstLaunch(defaults: defaults) {
            wipeCalls += 1
        }

        #expect(wipeCalls == 0)
        #expect(defaults.bool(forKey: KeychainBootstrap.firstLaunchKey))
    }

    @Test("Idempotent — back-to-back calls only wipe once")
    func idempotent() {
        let defaults = freshDefaults()
        var wipeCalls = 0
        let wipe: () -> Void = { wipeCalls += 1 }

        KeychainBootstrap.clearIfFirstLaunch(defaults: defaults, wipe: wipe)
        KeychainBootstrap.clearIfFirstLaunch(defaults: defaults, wipe: wipe)
        KeychainBootstrap.clearIfFirstLaunch(defaults: defaults, wipe: wipe)

        #expect(wipeCalls == 1)
    }
}
