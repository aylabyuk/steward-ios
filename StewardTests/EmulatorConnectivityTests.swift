import Testing

// Integration tests against the real Firebase emulators are deferred while the
// Firebase iOS SDK 12.x SwiftPM transitive-linking bug on Xcode 26 is open
// (https://github.com/firebase/firebase-ios-sdk/issues/15642). The test target
// is currently standalone (no app dependency, no Firebase products linked) so
// `xcodebuild test` works for pure-unit tests against StewardCore mocks.
// When the upstream bug is fixed, re-add Firebase products to the test target,
// restore TEST_HOST + the app target dependency in project.pbxproj, drop the
// `false &&` guard below, and replace `import` with whatever Firebase imports
// the bodies need.
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
