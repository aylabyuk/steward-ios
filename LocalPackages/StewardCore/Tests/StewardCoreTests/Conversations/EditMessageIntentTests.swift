import Foundation
import Testing
@testable import StewardCore

/// What the edit-message sheet should do with the bishop's typed
/// proposal before it sends a Twilio update. The view layer is dumb;
/// this helper is the single place where "should we actually write?"
/// is decided.
@Suite("EditMessageIntent.normalize — what counts as a real edit")
struct EditMessageIntentTests {

    @Test("Trimmed proposal that differs from current returns the trimmed body")
    func trimmedDifferentReturnsTrim() {
        #expect(EditMessageIntent.normalize(currentBody: "Hello", proposedBody: "Hello, friend") == "Hello, friend")
    }

    @Test("Whitespace is trimmed before comparison")
    func leadingTrailingWhitespaceTrimmed() {
        #expect(EditMessageIntent.normalize(currentBody: "Hi", proposedBody: "  Hi there  ") == "Hi there")
    }

    @Test("Proposal that matches current after trimming returns nil — no Twilio write")
    func unchangedReturnsNil() {
        #expect(EditMessageIntent.normalize(currentBody: "Hello", proposedBody: "Hello") == nil)
        #expect(EditMessageIntent.normalize(currentBody: "Hello", proposedBody: "  Hello  ") == nil)
    }

    @Test(
        "Empty / whitespace-only proposals never write — we don't accept blank messages",
        arguments: ["", " ", "\n", "   \t  "]
    )
    func blankProposalReturnsNil(proposed: String) {
        #expect(EditMessageIntent.normalize(currentBody: "Anything", proposedBody: proposed) == nil)
    }

    @Test("Multi-line proposals are preserved (only outer whitespace trims)")
    func multilineProposalsRoundTrip() {
        let proposal = "  line one\nline two  "
        #expect(EditMessageIntent.normalize(currentBody: "x", proposedBody: proposal) == "line one\nline two")
    }
}
