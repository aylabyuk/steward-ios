import Foundation
import Testing
@testable import StewardCore

private struct Thing: Codable, Equatable, Sendable {
    let id: String
    let name: String
}

private let validA = #"{"id":"a","name":"alpha"}"#.data(using: .utf8)!
private let validB = #"{"id":"b","name":"beta"}"#.data(using: .utf8)!
private let invalid = #"{"id":"c"}"#.data(using: .utf8)!

private let decoder: @Sendable (Data) throws -> Thing = { data in
    try JSONDecoder().decode(Thing.self, from: data)
}

@Suite("CollectionSubscription — list semantics")
@MainActor
struct CollectionSubscriptionTests {

    @Test("Stays loading=true when source is nil (path not ready)")
    func staysLoadingNilSource() async {
        let sub = CollectionSubscription<Thing>(source: nil, decoder: decoder)
        #expect(sub.loading == true)
        #expect(sub.items.isEmpty)
        #expect(sub.error == nil)
    }

    @Test("Empty docs array → loading=false, items=[]")
    func emptyCollection() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let sub = CollectionSubscription<Thing>(source: source, decoder: decoder)

        source.emit(CollectionSnap(docs: [], fromCache: false))

        try await waitUntilCS { sub.loading == false }
        #expect(sub.items.isEmpty)
        #expect(sub.error == nil)
    }

    @Test("All valid docs decode in order")
    func allValid() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let sub = CollectionSubscription<Thing>(source: source, decoder: decoder)

        source.emit(CollectionSnap(docs: [
            .init(id: "a", data: validA),
            .init(id: "b", data: validB),
        ], fromCache: false))

        try await waitUntilCS { sub.loading == false }
        #expect(sub.items.map(\.id) == ["a", "b"])
        #expect(sub.items[0].data == Thing(id: "a", name: "alpha"))
        #expect(sub.items[1].data == Thing(id: "b", name: "beta"))
    }

    @Test("One malformed doc is skipped, the rest survive")
    func malformedSkipped() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let sub = CollectionSubscription<Thing>(
            source: source, decoder: decoder, path: "wards/stv1/meetings"
        )

        source.emit(CollectionSnap(docs: [
            .init(id: "a", data: validA),
            .init(id: "broken", data: invalid),
            .init(id: "b", data: validB),
        ], fromCache: false))

        try await waitUntilCS { sub.loading == false }
        #expect(sub.items.map(\.id) == ["a", "b"])
        #expect(sub.error == nil, "one bad doc must not surface as a list-level error")
    }

    @Test("Source error → loading=false, items=[], error set")
    func sourceError() async throws {
        struct Boom: Error {}
        let source = MockSnapshotSource<CollectionSnap>()
        let sub = CollectionSubscription<Thing>(source: source, decoder: decoder)

        source.emit(error: Boom())

        try await waitUntilCS { sub.loading == false }
        #expect(sub.items.isEmpty)
        #expect(sub.error is Boom)
    }
}

@MainActor
private func waitUntilCS(
    timeout: Duration = .milliseconds(500),
    _ predicate: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("waitUntilCS timed out after \(timeout)")
}
