import Foundation

/// Bubble-reaction overlay persisted on Twilio message attributes.
/// Lives alongside any other attribute kind (`status-change`,
/// `invitation`, `responseType`, `message-deleted`) — reactions are
/// metadata on a message, not a discriminator. A message that has
/// reactions is still its original kind and still subject to the
/// usual edit/delete rules.
///
/// Storage shape on Twilio: `{ "reactions": { "👍": ["uid:a", …], … } }`.
/// Toggle is idempotent (re-toggling removes), buckets that empty out
/// are dropped from the map so a no-reaction bubble round-trips with
/// no `reactions` payload at all.
public struct Reactions: Sendable, Equatable, Hashable, Codable {
    public let entries: [String: [String]]

    public static let empty = Reactions(entries: [:])

    /// Fixed 6-emoji palette. Single source of truth for both iOS
    /// and web — neither platform should hard-code its own list. The
    /// order here is the order the contextMenu / picker surfaces.
    public static let palette: [String] = ["👍", "❤️", "🙏", "✅", "😊", "😮"]

    public init(entries: [String: [String]]) {
        // Dedupe identities within each bucket so a roundtrip-induced
        // duplicate doesn't inflate counts. Keep insertion order
        // within each bucket so a second tap still removes "the most
        // recent" instance predictably.
        var deduped: [String: [String]] = [:]
        for (emoji, identities) in entries {
            var seen = Set<String>()
            var ordered: [String] = []
            for identity in identities where seen.insert(identity).inserted {
                ordered.append(identity)
            }
            if ordered.isEmpty == false {
                deduped[emoji] = ordered
            }
        }
        self.entries = deduped
    }

    public var nonEmpty: Bool { entries.isEmpty == false }

    public func count(for emoji: String) -> Int {
        entries[emoji]?.count ?? 0
    }

    public func includes(emoji: String, identity: String) -> Bool {
        entries[emoji]?.contains(identity) ?? false
    }

    /// Stable ordering for chip rendering — palette order first
    /// (so 👍 always renders before ❤️), then any unknown emojis the
    /// other platform might have added (alphabetical for stability).
    public var orderedEntries: [(emoji: String, identities: [String])] {
        let known = Self.palette.compactMap { emoji -> (String, [String])? in
            guard let identities = entries[emoji], identities.isEmpty == false else { return nil }
            return (emoji, identities)
        }
        let unknown = entries.keys
            .filter { Self.palette.contains($0) == false }
            .sorted()
            .compactMap { emoji -> (String, [String])? in
                guard let identities = entries[emoji], identities.isEmpty == false else { return nil }
                return (emoji, identities)
            }
        return (known + unknown).map { (emoji: $0.0, identities: $0.1) }
    }

    /// Toggle the (emoji, identity) pair: add if absent, remove if
    /// present. Empty buckets collapse out of `entries`.
    public func toggled(emoji: String, identity: String) -> Reactions {
        var next = entries
        var bucket = next[emoji] ?? []
        if let idx = bucket.firstIndex(of: identity) {
            bucket.remove(at: idx)
        } else {
            bucket.append(identity)
        }
        if bucket.isEmpty {
            next.removeValue(forKey: emoji)
        } else {
            next[emoji] = bucket
        }
        return Reactions(entries: next)
    }

    /// Parse from the raw Twilio attributes dictionary. Returns
    /// `.empty` for missing / malformed payloads — reactions are
    /// best-effort overlay data; a malformed payload should never
    /// crash the bubble.
    public static func parse(_ raw: [String: Any]?) -> Reactions {
        guard let raw,
              let payload = raw["reactions"] as? [String: Any] else { return .empty }
        var entries: [String: [String]] = [:]
        for (emoji, value) in payload {
            guard let identities = value as? [String] else { continue }
            entries[emoji] = identities
        }
        return Reactions(entries: entries)
    }

    /// Write back to a raw Twilio attributes dict — preserves any
    /// other keys (kind, status, responseType, etc.) and either
    /// updates or removes the `reactions` key based on whether
    /// there's anything to write.
    public func merging(into raw: [String: Any]) -> [String: Any] {
        var next = raw
        if entries.isEmpty {
            next.removeValue(forKey: "reactions")
        } else {
            next["reactions"] = entries
        }
        return next
    }

    // MARK: - Codable (bare-map wire format)

    /// On-the-wire JSON is the bare `{ "👍": [...], "❤️": [...] }`
    /// shape, not `{ "entries": {...} }`. Custom (de)coding so a
    /// JSONDecoder run against either the raw Twilio attributes or
    /// any future Firestore mirror reads/writes that shape directly.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: [String]].self)
        self.init(entries: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(entries)
    }
}
