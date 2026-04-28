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
        let host = EmulatorConfig.host

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
