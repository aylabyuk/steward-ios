import Foundation
import CryptoKit

/// Apple Sign-In requires a per-request nonce: the SHA256 hash is sent to
/// Apple as part of the auth request, and the raw value is later passed
/// to `OAuthProvider.appleCredential(...)` so Firebase can verify the
/// returned identity token wasn't replayed. This helper generates a
/// cryptographically random URL-safe string and its SHA256 hex digest.
enum Nonce {
    /// Random URL-safe alphanumeric string. 32 chars is the
    /// canonical length used in Apple's "Sign in with Apple" sample code.
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array(
            "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._"
        )
        var result = ""
        result.reserveCapacity(length)
        while result.count < length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            precondition(status == errSecSuccess, "Failed to generate secure random byte")
            // Reject bytes that would bias the distribution outside the charset.
            if byte < charset.count {
                result.append(charset[Int(byte)])
            }
        }
        return result
    }

    /// Hex SHA256 digest. Apple compares the returned identity token's
    /// `nonce` claim against this value.
    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
