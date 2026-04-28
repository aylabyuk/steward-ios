import Foundation
import Observation

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
    private(set) var lastError: Error?

    private var task: Task<Void, Never>?

    init() {
        task = Task { [weak self] in
            for await user in Self.authStateStream() {
                guard let self else { return }
                self.uid = user?.uid
                self.email = user?.email
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
