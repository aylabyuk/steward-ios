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
        if EmulatorConfig.isEnabled {
            // The committed GoogleService-Info.plist is for the production
            // Firebase project (steward-prod-65a36). The Firebase emulator suite
            // run by the web repo is configured for the dev project
            // (steward-dev-5e4dc). Without this override, Firestore requests
            // get stamped with the prod project ID and the emulator's
            // single-project mode rejects every read with a rules-eval failure.
            // Overriding lets the same plist work for prod (real backend) and
            // dev (emulator) without juggling two files.
            guard
                let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                let options = FirebaseOptions(contentsOfFile: path)
            else {
                FirebaseApp.configure()
                return
            }
            options.projectID = "steward-dev-5e4dc"
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }

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
