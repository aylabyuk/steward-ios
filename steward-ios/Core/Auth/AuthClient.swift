import Foundation
import Observation
import StewardCore

#if canImport(FirebaseAuth)
import FirebaseAuth

/// Observable auth client. Bridges Firebase Auth's
/// `addStateDidChangeListener` callback API into a `MainActor`-isolated
/// `AsyncStream` we consume with a single owned task. That avoids relying on
/// `MainActor.assumeIsolated` inside Firebase's callback (Firebase fires on
/// the main thread but doesn't carry the guarantee in the type system).
@Observable
@MainActor
final class AuthClient {
    private(set) var uid: String?
    private(set) var email: String?
    private(set) var displayName: String?
    private(set) var photoURL: URL?
    private(set) var lastError: Error?

    private var task: Task<Void, Never>?

    init() {
        task = Task { [weak self] in
            for await user in Self.authStateStream() {
                guard let self else { return }
                self.uid = user?.uid
                self.email = user?.email
                self.displayName = user?.displayName
                self.photoURL = user?.photoURL
            }
        }
    }

    isolated deinit {
        task?.cancel()
    }

    var isSignedIn: Bool {
        uid != nil
    }

    func signIn(email: String, password: String) async {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            self.lastError = nil
        } catch {
            self.lastError = error
        }
    }

    /// Google Sign-In via Firebase's `OAuthProvider`. Routes through
    /// `ASWebAuthenticationSession` and reaches the real Google OAuth
    /// flow in production. **In DEBUG builds the button always
    /// short-circuits through email/password sign-in** because
    /// Firebase Auth iOS's `OAuthProvider.getCredentialWith` doesn't
    /// reliably honor `useEmulator(...)` — the handler page either
    /// dead-ends on `about:blank` or sends the user to real Google
    /// despite the emulator flag. Real Google OAuth against the
    /// emulator is meaningless anyway, so this trades a config
    /// dependency (`USE_EMULATOR=1`) for an unconditional dev path.
    /// If the emulator isn't running, sign-in fails loudly with
    /// "Network error" rather than silently sending you to real
    /// Google — much easier to debug. The emulator auto-creates
    /// accounts on first sign-in, so this lands as the seeded
    /// `bishop@e2e.local` user without any password setup.
    func signInWithGoogle() async {
        do {
            #if DEBUG
            _ = try await Auth.auth().signIn(
                withEmail: "bishop@e2e.local",
                password: "test1234"
            )
            self.lastError = nil
            return
            #else
            let provider = OAuthProvider(providerID: "google.com")
            let credential = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthCredential, Error>) in
                provider.getCredentialWith(nil) { credential, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let credential {
                        continuation.resume(returning: credential)
                    } else {
                        continuation.resume(throwing: AuthError.missingCredential)
                    }
                }
            }
            _ = try await Auth.auth().signIn(with: credential)
            self.lastError = nil
            #endif
        } catch {
            self.lastError = error
        }
    }

    /// Sign in with Apple. The caller (typically `SignInWithAppleButton`'s
    /// `onCompletion` closure) provides the raw nonce that was hashed in
    /// the request, plus the identity token returned by Apple. Firebase
    /// uses the nonce to verify the token wasn't replayed.
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            _ = try await Auth.auth().signIn(with: credential)
            self.lastError = nil
        } catch {
            self.lastError = error
        }
    }

    /// Surface an error that originated outside `AuthClient` itself —
    /// e.g. the SwiftUI `SignInWithAppleButton` callback path that
    /// hands us an `ASAuthorizationError` to display.
    func recordError(_ error: Error) {
        self.lastError = error
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.lastError = nil
        } catch {
            self.lastError = error
        }
    }

    /// Wraps Firebase's listener-handle API as an `AsyncStream`. The
    /// continuation owns the handle and removes the listener when the consumer
    /// terminates (task cancelled or stream finished).
    enum AuthError: LocalizedError {
        case missingCredential
        var errorDescription: String? {
            switch self {
            case .missingCredential:
                "OAuth provider returned without a credential or an error."
            }
        }
    }

    private nonisolated static func authStateStream() -> AsyncStream<User?> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: User?.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let handle = Auth.auth().addStateDidChangeListener { _, user in
            continuation.yield(user)
        }
        continuation.onTermination = { _ in
            Auth.auth().removeStateDidChangeListener(handle)
        }
        return stream
    }
}
#endif
