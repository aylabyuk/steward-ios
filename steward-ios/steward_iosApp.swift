import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@main
struct steward_iosApp: App {
    /// Required by Firebase Auth's OAuth flow. Without it,
    /// GoogleUtilities's swizzler can't attach (logs `I-SWZ001014`)
    /// and Sign-In with Google dead-ends on a blank
    /// `ASWebAuthenticationSession` page. The adaptor also makes the
    /// scene-based `.onOpenURL` route through a real
    /// `UIApplicationDelegate`, which Firebase relies on for some
    /// internal lifecycle hooks (APNS later, OAuth callbacks now).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // FirebaseSetup.configure() and FontAudit moved into
    // AppDelegate.application(_:didFinishLaunchingWithOptions:) — see
    // the comment in AppDelegate.swift for why timing matters.

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Defence in depth — the AppDelegate's
                    // `application(_:open:options:)` is the primary
                    // hand-off, this scene-level hook covers any path
                    // that bypasses the delegate.
                    #if canImport(FirebaseAuth)
                    _ = Auth.auth().canHandle(url)
                    #endif
                }
        }
    }
}
