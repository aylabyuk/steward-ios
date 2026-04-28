import SwiftUI

@main
struct steward_iosApp: App {
    init() {
        FirebaseSetup.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
