import Foundation
import Testing
@testable import StewardCore

/// Drives the merge the chat observer applies when reconciling its
/// in-memory message list against a fresh bulk fetch. Twilio iOS
/// SDK's per-conversation `messageAdded` delegate can fire during
/// initial sync — concurrently with our bulk `getLastMessages` call
/// — so the bulk result *cannot* simply overwrite, or we lose the
/// delegate-pushed messages and the thread renders empty until the
/// next observer is constructed (the original "close and reopen
/// shows the messages" symptom). Merge wins by SID, breaks ties in
/// favor of the incoming snapshot, and re-sorts by Twilio's
/// monotonic index.
@Suite("ChatMessage.Array.merged(with:) — observer initial-load reconciliation")
struct ChatMessageMergeTests {

    private func msg(sid: String, index: Int, body: String = "x") -> ChatMessage {
        ChatMessage(
            sid: sid, index: index, author: "uid:bishop",
            body: body, dateCreated: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("Empty existing + non-empty incoming yields just the incoming, sorted by index")
    func emptyExistingTakesIncoming() {
        let existing: [ChatMessage] = []
        let incoming = [msg(sid: "b", index: 1), msg(sid: "a", index: 0)]
        #expect(existing.merged(with: incoming).map(\.sid) == ["a", "b"])
    }

    @Test("Non-empty existing + empty incoming preserves existing — bulk fetch did not return data")
    func emptyIncomingPreservesExisting() {
        let existing = [msg(sid: "a", index: 0)]
        #expect(existing.merged(with: []).map(\.sid) == ["a"])
    }

    @Test("Disjoint existing + incoming merge into one sorted-by-index list")
    func disjointMerge() {
        let existing = [msg(sid: "a", index: 0)]
        let incoming = [msg(sid: "b", index: 1)]
        #expect(existing.merged(with: incoming).map(\.sid) == ["a", "b"])
    }

    @Test("Overlapping SIDs: incoming wins so a fresh bulk fetch updates dateUpdated/edits")
    func incomingWinsOnConflict() {
        let existing = [msg(sid: "a", index: 0, body: "stale")]
        let incoming = [msg(sid: "a", index: 0, body: "fresh")]
        let merged = existing.merged(with: incoming)
        #expect(merged.count == 1)
        #expect(merged.first?.body == "fresh")
    }

    @Test("Final order is by Twilio index — out-of-order inputs still produce a monotonic list")
    func outputIsSortedByIndex() {
        let existing = [msg(sid: "c", index: 2), msg(sid: "a", index: 0)]
        let incoming = [msg(sid: "b", index: 1), msg(sid: "d", index: 3)]
        #expect(existing.merged(with: incoming).map(\.sid) == ["a", "b", "c", "d"])
    }

    @Test("Pinned regression: bulk fetch returning [] does not wipe delegate-pushed messages")
    func bulkEmptyDoesNotOverwriteDelegate() {
        // The exact race that produced "messages don't appear until I
        // close and reopen": messageAdded delegate populated `existing`
        // during initial sync; the bulk fetch then returned an empty
        // list because sync hadn't completed yet on the conversation.
        let delegatePushed = [
            msg(sid: "m0", index: 0),
            msg(sid: "m1", index: 1),
        ]
        let bulkBeforeSync: [ChatMessage] = []
        let merged = delegatePushed.merged(with: bulkBeforeSync)
        #expect(merged.count == 2)
        #expect(merged.map(\.sid) == ["m0", "m1"])
    }
}
