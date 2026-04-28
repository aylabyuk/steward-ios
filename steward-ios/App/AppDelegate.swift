import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Minimal UIApplicationDelegate so GoogleUtilities's swizzler can attach
/// (it logs `I-SWZ001014` otherwise) and Firebase Auth's OAuth flow gets
/// its URL-callback path wired up. Without this, Sign-In with Google
/// dead-ends on a blank `ASWebAuthenticationSession` page — the SDK
/// builds the handler URL but the redirect-back machinery never
/// completes because the app delegate proxy can't intercept the
/// custom-scheme open.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase HERE rather than in `App.init()`. Firebase's
        // GoogleUtilities AppDelegateSwizzler runs synchronously inside
        // `FirebaseApp.configure()` and snapshots the current
        // `UIApplication.shared.delegate`. If we configure from
        // `App.init()`, that runs before UIApplicationMain has finished
        // installing this adaptor as the delegate — the swizzler then
        // sees a non-conforming proxy, logs `I-SWZ001014`, and the
        // OAuth callback path is never wired (`ASWebAuthenticationSession`
        // ends up on `about:blank`). Configuring from
        // `didFinishLaunchingWithOptions` guarantees `self` is already
        // the application delegate.
        FirebaseSetup.configure()
        #if DEBUG
        FontAudit.dumpLoadedFonts()
        #endif
        return true
    }

    /// Hand the OAuth-redirect URL (custom scheme:
    /// `com.googleusercontent.apps.<reversed-client-id>://firebaseauth/link?…`)
    /// to Firebase Auth so it can complete the in-flight presentation.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(FirebaseAuth)
        return Auth.auth().canHandle(url)
        #else
        return false
        #endif
    }
}
