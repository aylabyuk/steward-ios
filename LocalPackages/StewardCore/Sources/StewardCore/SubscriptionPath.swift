import Foundation

/// Mirrors the segment-readiness check from `src/hooks/_sub.ts:27-29` on the
/// web. Returns `nil` (= "not ready, stay loading") if the array is empty or
/// any segment is `nil` / empty. Otherwise returns the segments joined by `/`,
/// suitable for `Firestore.firestore().document(path)` or `.collection(path)`.
public enum SubscriptionPath {
    public static func key(_ segments: [String?]) -> String? {
        guard segments.isEmpty == false else { return nil }
        var parts: [String] = []
        parts.reserveCapacity(segments.count)
        for segment in segments {
            guard let value = segment, value.isEmpty == false else { return nil }
            parts.append(value)
        }
        return parts.joined(separator: "/")
    }
}
