import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@main
struct steward_iosApp: App {
    init() {
        FirebaseSetup.configure()
        #if DEBUG
        FontAudit.dumpLoadedFonts()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Firebase Auth's OAuth flow uses SFSafariViewController, which
                    // doesn't auto-intercept custom-scheme redirects. The chooser
                    // (production handler or Auth emulator's fake chooser) redirects
                    // to a `com.googleusercontent.apps.<reversed-client-id>://firebaseauth/link?…`
                    // deep link; iOS forwards it here, and we hand it to Firebase
                    // Auth so it can finish the in-flight presentation.
                    #if canImport(FirebaseAuth)
                    _ = Auth.auth().canHandle(url)
                    #endif
                }
        }
    }
}
