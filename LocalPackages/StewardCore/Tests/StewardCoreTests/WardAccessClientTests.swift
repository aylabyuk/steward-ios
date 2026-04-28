import Foundation
import Testing
@testable import StewardCore

/// User-facing behaviour tests for the post-sign-in ward allowlist gate.
/// Each test describes what the bishopric user observes (or what
/// `RootView` would route to) given a particular collection-group result.

private func docFor(
    wardId: String,
    uid: String,
    role: String? = nil,
    displayName: String? = nil
) -> CollectionSnap.Doc {
    var fields: [String: String] = [:]
    if let role { fields["role"] = role }
    if let displayName { fields["displayName"] = displayName }
    let payload = (try? JSONSerialization.data(withJSONObject: fields)) ?? Data()
    return CollectionSnap.Doc(id: "\(wardId)/\(uid)", data: payload)
}

@Suite("WardAccessClient — what the user sees after Auth resolves")
@MainActor
struct WardAccessClientTests {

    @Test("Source is nil → state stays `.checking` (e.g. while we wait for an email)")
    func nilSourceStaysChecking() async {
        let client = WardAccessClient(source: nil)
        #expect(client.state == .checking)
    }

    @Test("Empty member docs → `.none` (signed in but not allowlisted)")
    func noActiveMembers() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let client = WardAccessClient(source: source)

        source.emit(CollectionSnap(docs: [], fromCache: false))

        try await waitUntilWA { client.state == .none }
    }

    @Test("Exactly one active member → `.single(member)` parsed from the doc path")
    func oneActiveMember() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let client = WardAccessClient(source: source)

        source.emit(CollectionSnap(docs: [
            docFor(wardId: "stv1", uid: "uid-bishop", role: "bishopric", displayName: "Bishop Smith")
        ], fromCache: false))

        try await waitUntilWA {
            if case .single = client.state { return true } else { return false }
        }

        let m = try #require({ () -> MemberAccess? in
            if case .single(let m) = client.state { return m } else { return nil }
        }())
        #expect(m.wardId == "stv1")
        #expect(m.uid == "uid-bishop")
        #expect(m.role == "bishopric")
        #expect(m.displayName == "Bishop Smith")
    }

    @Test("Two active member docs → `.multiple` preserves their delivery order for the picker")
    func multipleActiveMembers() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let client = WardAccessClient(source: source)

        source.emit(CollectionSnap(docs: [
            docFor(wardId: "stv1", uid: "uid-bishop", role: "bishopric"),
            docFor(wardId: "stv2", uid: "uid-bishop", role: "clerk"),
        ], fromCache: false))

        try await waitUntilWA {
            if case .multiple = client.state { return true } else { return false }
        }

        let members = try #require({ () -> [MemberAccess]? in
            if case .multiple(let xs) = client.state { return xs } else { return nil }
        }())
        #expect(members.map(\.wardId) == ["stv1", "stv2"])
    }

    @Test("Source error → state collapses to `.none` (matches web's useWardAccess.ts:75-79)")
    func sourceErrorIsTreatedAsNoAccess() async throws {
        struct Boom: Error {}
        let source = MockSnapshotSource<CollectionSnap>()
        let client = WardAccessClient(source: source)

        source.emit(error: Boom())

        try await waitUntilWA { client.state == .none }
    }

    @Test("Doc with non-`wardId/uid` ID is dropped silently rather than crashing")
    func malformedDocIdsAreSkipped() async throws {
        let source = MockSnapshotSource<CollectionSnap>()
        let client = WardAccessClient(source: source)

        source.emit(CollectionSnap(docs: [
            CollectionSnap.Doc(id: "no-slash-here", data: Data()),  // garbage
            docFor(wardId: "stv1", uid: "uid-good")
        ], fromCache: false))

        try await waitUntilWA {
            if case .single = client.state { return true } else { return false }
        }
        if case .single(let m) = client.state {
            #expect(m.wardId == "stv1")
            #expect(m.uid == "uid-good")
        }
    }
}

@MainActor
private func waitUntilWA(
    timeout: Duration = .milliseconds(500),
    _ predicate: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("waitUntilWA timed out after \(timeout)")
}
