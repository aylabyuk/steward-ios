import Testing
@testable import steward_ios

#if canImport(FirebaseCore)
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
