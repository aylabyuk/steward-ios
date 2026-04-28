import SwiftUI

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
        }
    }
}
