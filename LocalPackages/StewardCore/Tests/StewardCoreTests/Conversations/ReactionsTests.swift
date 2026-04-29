import Foundation
import Testing
@testable import StewardCore

/// What the chat-bubble reaction logic does. The stored shape is a
/// `[emoji: [identity]]` map persisted on Twilio message attributes
/// (overlay metadata — coexists with `kind: "status-change"` etc.).
/// Toggle = idempotent add-or-remove for the (emoji, identity) pair,
/// last-write-wins on simultaneous taps from different clients.
@Suite("Reactions — toggle and lookup on the chat-bubble reaction overlay")
struct ReactionsTests {

    private let bishop = "uid:bishop-a"
    private let speaker = "speaker:invitation-x"

    @Test("Empty reactions report no entries and have no chips")
    func emptyState() {
        let r = Reactions.empty
        #expect(r.nonEmpty == false)
        #expect(r.count(for: "👍") == 0)
        #expect(r.includes(emoji: "👍", identity: bishop) == false)
        #expect(r.orderedEntries.isEmpty)
    }

    @Test("Toggle with no prior reaction adds the identity to that emoji's bucket")
    func toggleAdd() {
        let r = Reactions.empty.toggled(emoji: "👍", identity: bishop)
        #expect(r.includes(emoji: "👍", identity: bishop))
        #expect(r.count(for: "👍") == 1)
        #expect(r.nonEmpty)
    }

    @Test("Toggle a second time removes the identity (idempotent off)")
    func toggleOff() {
        let added = Reactions.empty.toggled(emoji: "👍", identity: bishop)
        let removed = added.toggled(emoji: "👍", identity: bishop)
        #expect(removed.includes(emoji: "👍", identity: bishop) == false)
        #expect(removed.count(for: "👍") == 0)
        #expect(removed.nonEmpty == false)
    }

    @Test("Two distinct identities can react with the same emoji — both stay")
    func twoIdentitiesSameEmoji() {
        let r = Reactions.empty
            .toggled(emoji: "👍", identity: bishop)
            .toggled(emoji: "👍", identity: speaker)
        #expect(r.count(for: "👍") == 2)
        #expect(r.includes(emoji: "👍", identity: bishop))
        #expect(r.includes(emoji: "👍", identity: speaker))
    }

    @Test("One identity reacting twice with the same emoji is deduped to one entry")
    func dedupeRepeatedAdd() {
        // Defensive: Twilio attribute roundtrips on the same message
        // could produce duplicates; the toggle path that adds should
        // never grow the bucket past one entry per identity.
        let r = Reactions(entries: ["👍": [bishop, bishop]])
        #expect(r.count(for: "👍") == 1, "duplicate identity entries collapse to one")
    }

    @Test("Different emojis from the same identity stack independently")
    func independentEmojis() {
        let r = Reactions.empty
            .toggled(emoji: "👍", identity: bishop)
            .toggled(emoji: "🙏", identity: bishop)
        #expect(r.count(for: "👍") == 1)
        #expect(r.count(for: "🙏") == 1)
        #expect(r.orderedEntries.count == 2)
    }

    @Test("An emoji bucket emptied by toggle-off is removed from the entries map")
    func emptyBucketCollapses() {
        // Avoids leaving "👍": [] residue on the Twilio attributes
        // payload — a no-reaction bubble should round-trip through
        // serialization with `reactions` absent or empty, not as a
        // map of empty arrays.
        let r = Reactions.empty
            .toggled(emoji: "👍", identity: bishop)
            .toggled(emoji: "👍", identity: bishop)
        #expect(r.orderedEntries.isEmpty)
        #expect(r.entries["👍"] == nil)
    }

    @Test("Decoding a JSON payload yields the same shape as round-tripping toggles")
    func decodeFromJSON() throws {
        let json = """
        {"👍": ["uid:bishop-a", "speaker:invitation-x"], "🙏": ["uid:bishop-a"]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Reactions.self, from: json)
        #expect(decoded.count(for: "👍") == 2)
        #expect(decoded.count(for: "🙏") == 1)
        #expect(decoded.includes(emoji: "🙏", identity: bishop))
    }

    @Test("Encoding round-trips through JSON without losing entries")
    func encodeRoundTrip() throws {
        let original = Reactions.empty
            .toggled(emoji: "👍", identity: bishop)
            .toggled(emoji: "❤️", identity: speaker)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reactions.self, from: data)
        #expect(decoded == original)
    }

    @Test("Palette is the fixed 6-emoji set; iOS UI surfaces these in order")
    func paletteOrder() {
        // Pinned so neither platform's UI silently reorders or drops
        // an emoji — both iOS and web read from this list.
        #expect(Reactions.palette == ["👍", "❤️", "🙏", "✅", "😊", "😮"])
    }
}
