import Testing
@testable import steward_ios

// Firebase iOS SDK 12.x has a SwiftPM transitive-linking bug on Xcode 26 that
// prevents FirebaseFirestore_PackageProduct.framework from linking abseil
// symbols inside the test bundle (the app target itself links cleanly).
// Tracked at https://github.com/firebase/firebase-ios-sdk/issues/15642 — when
// upstream resolves it, drop the `false &&` guard below and re-enable.
#if false && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore

@Suite("Emulator connectivity (integration)", .serialized)
struct EmulatorConnectivityTests {

    init() {
        FirebaseSetup.configure()
    }

    @Test("Bishop can sign in against the Auth emulator")
    func bishopCanSignIn() async throws {
        let result = try await Auth.auth().signIn(
            withEmail: "bishop@e2e.local",
            password: "test1234"
        )
        #expect(result.user.uid == "G2Bcy1N7aLAAkZd94WYqDwJ9cYwV")
    }

    @Test("wards/stv1 document is reachable via Firestore emulator")
    func wardDocReads() async throws {
        let snap = try await Firestore.firestore()
            .collection("wards")
            .document("stv1")
            .getDocument()
        #expect(snap.exists)
    }
}
#endif
