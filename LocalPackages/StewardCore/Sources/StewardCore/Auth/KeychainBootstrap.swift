import Foundation
import Security

/// Wipe any keychain items left behind by a previous install of this
/// app. Keychain items survive app deletion (Apple DTS confirmed:
/// "expected behaviour despite being an obvious privacy concern" —
/// Quinn "The Eskimo!", *SecItem: Pitfalls and Best Practices*), so
/// without this sweep a fresh install on a previously-used device
/// inherits stale Firebase Auth tokens, expired identity certificates,
/// and any other keychain residue.
///
/// Gated on a `UserDefaults` flag — `UserDefaults` IS cleared on
/// uninstall, so its absence is the canonical "first launch on this
/// install" signal (per `common-anti-patterns.md` § Anti-Pattern #9).
///
/// **Threading note.** Despite the general "no `SecItem*` on the main
/// thread" rule, this intentionally runs on the main thread inside
/// `application(_:didFinishLaunchingWithOptions:)`: the cleanup must
/// complete before any background SDK (e.g. Firebase Auth) reads from
/// the keychain on its own thread. Five `SecItemDelete` calls take a
/// few milliseconds total and only fire once per install.
///
/// **Test seam.** The `wipe` closure parameter lets tests substitute a
/// no-op so the host's keychain is never touched during `swift test`.
/// Production callers omit it and get the real `wipeAllKeychain`.
public enum KeychainBootstrap {

    /// Public so tests can assert the flag was set without hardcoding
    /// the magic string. Stable across releases — renaming would
    /// re-trigger the wipe on every existing install.
    public static let firstLaunchKey = "hasLaunchedBefore"

    public static func clearIfFirstLaunch(
        defaults: UserDefaults = .standard,
        wipe: () -> Void = wipeAllKeychain
    ) {
        guard !defaults.bool(forKey: firstLaunchKey) else { return }
        wipe()
        defaults.set(true, forKey: firstLaunchKey)
    }

    /// Run `SecItemDelete` across all five `kSecClass` types. Including
    /// `kSecAttrSynchronizable: kSecAttrSynchronizableAny` ensures
    /// iCloud Keychain items are also matched.
    public static func wipeAllKeychain() {
        let classes: [CFString] = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity,
        ]
        for secClass in classes {
            let query: [CFString: Any] = [
                kSecClass: secClass,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            ]
            let status = SecItemDelete(query as CFDictionary)
            // `errSecSuccess` (item deleted) and `errSecItemNotFound`
            // (nothing to delete) are both expected outcomes for this
            // best-effort first-launch sweep. Other codes are unusual
            // but mustn't block launch — they only mean the wipe was
            // partial. Surfaced under DEBUG so they're noticeable
            // during dev without crashing user installs.
            if status != errSecSuccess && status != errSecItemNotFound {
                #if DEBUG
                print("[KeychainBootstrap] SecItemDelete returned \(status) for class \(secClass)")
                #endif
            }
        }
    }
}
