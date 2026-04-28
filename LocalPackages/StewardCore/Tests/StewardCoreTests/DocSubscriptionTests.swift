import Foundation
import Testing
@testable import StewardCore

private struct Thing: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

private let validJSON = """
{"id":"abc","name":"alpha"}
""".data(using: .utf8)!

private let invalidJSON = """
{"id":"abc"}
""".data(using: .utf8)!

private let decoder: @Sendable (Data) throws -> Thing = { data in
    try JSONDecoder().decode(Thing.self, from: data)
}

private struct DummyError: Error, Equatable {}

@Suite("DocSubscription — core behaviour")
@MainActor
struct DocSubscriptionTests {

    @Test("Stays in loading=true forever when source is nil (path not ready)")
    func staysLoadingWhenSourceNil() async {
        let sub = DocSubscription<Thing>(source: nil, decoder: decoder)
        #expect(sub.loading == true)
        #expect(sub.data == nil)
        #expect(sub.error == nil)
    }

    @Test("Successful snapshot flips loading=false and decodes data")
    func dataArrives() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)
        #expect(sub.loading == true)

        source.emit(DocSnap(exists: true, fromCache: false, data: validJSON))

        try await waitUntil { sub.loading == false }
        #expect(sub.data == Thing(id: "abc", name: "alpha"))
        #expect(sub.error == nil)
    }

    @Test("Non-existent document → loading=false, data=nil, no error")
    func nonExistentDoc() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)

        source.emit(DocSnap(exists: false, fromCache: false, data: nil))

        try await waitUntil { sub.loading == false }
        #expect(sub.data == nil)
        #expect(sub.error == nil)
    }

    @Test("Decode failure surfaces error, leaves data=nil")
    func decodeFailure() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)

        source.emit(DocSnap(exists: true, fromCache: false, data: invalidJSON))

        try await waitUntil { sub.loading == false }
        #expect(sub.data == nil)
        #expect(sub.error != nil)
    }

    @Test("Skips fromCache=true && !exists() first fire, surfaces only the authoritative result")
    func skipsCacheMissFirstFire() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)

        // First fire: cache miss. Web behaviour: ignore entirely.
        source.emit(DocSnap(exists: false, fromCache: true, data: nil))
        // Give the consumer task a tick to process — we expect no state change.
        try await Task.sleep(for: .milliseconds(15))
        #expect(sub.loading == true, "cache-miss fire should not flip loading")
        #expect(sub.data == nil)
        #expect(sub.error == nil)

        // Second fire: authoritative result. Now state should resolve.
        source.emit(DocSnap(exists: true, fromCache: false, data: validJSON))
        try await waitUntil { sub.loading == false }
        #expect(sub.data == Thing(id: "abc", name: "alpha"))
    }

    @Test("Cache hit (fromCache=true && exists()) does NOT get skipped")
    func cacheHitNotSkipped() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)

        // fromCache=true but the doc DOES exist — that's a real cache hit, valid.
        source.emit(DocSnap(exists: true, fromCache: true, data: validJSON))

        try await waitUntil { sub.loading == false }
        #expect(sub.data == Thing(id: "abc", name: "alpha"))
    }

    @Test("Source error surfaces, loading=false, data=nil")
    func sourceErrorPropagates() async throws {
        let source = MockSnapshotSource<DocSnap>()
        let sub = DocSubscription<Thing>(source: source, decoder: decoder)

        source.emit(error: DummyError())

        try await waitUntil { sub.loading == false }
        #expect(sub.data == nil)
        #expect(sub.error is DummyError)
    }
}

/// Tiny polling helper — Swift Testing doesn't have a built-in "wait for
/// observable to change". Cap at 500ms so a stuck test fails fast.
@MainActor
private func waitUntil(
    timeout: Duration = .milliseconds(500),
    _ predicate: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("waitUntil timed out after \(timeout)")
}
