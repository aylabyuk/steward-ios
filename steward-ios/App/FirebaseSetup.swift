import Foundation
import StewardCore

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
#endif

enum FirebaseSetup {
    static func configure() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()

        guard EmulatorConfig.isEnabled else { return }
        // The web repo's `firebase.json` binds emulators to `0.0.0.0`
        // (all interfaces). That's a bind address — clients can't
        // reliably *connect* to it. WebKit (used by
        // `ASWebAuthenticationSession` for the OAuth handler page)
        // silently fails to load `http://0.0.0.0:...`, which is what
        // produced the blank-page sign-in flow. Normalize here so any
        // EMULATOR_HOST value of `0.0.0.0` becomes loopback —
        // `127.0.0.1` is what every host on this machine routes
        // emulator traffic through anyway.
        let host = EmulatorConfig.host == "0.0.0.0" ? "127.0.0.1" : EmulatorConfig.host

        Auth.auth().useEmulator(withHost: host, port: 9099)

        let settings = Firestore.firestore().settings
        settings.host = "\(host):8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings

        Functions.functions().useEmulator(withHost: host, port: 5001)
        #else
        // Firebase SPM packages not added yet — see CLAUDE.md "Local development".
        // Once added, this no-op stub is replaced by the real configuration above.
        _ = EmulatorConfig.isEnabled
        #endif
    }
}
