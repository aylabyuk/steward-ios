import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
struct RootView: View {
    @State private var auth = AuthClient()

    var body: some View {
        Group {
            if auth.isSignedIn {
                ScheduleView(auth: auth)
            } else {
                LoginView(auth: auth)
            }
        }
        .animation(.default, value: auth.isSignedIn)
    }
}

#Preview {
    RootView()
}
#else
// Firebase isn't linked yet — fall back to a placeholder so previews and
// pre-SPM builds still compile. The real RootView replaces this once
// Firebase products are available.
struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Steward")
                .font(.title2.weight(.semibold))
            Text("Firebase not linked — placeholder UI.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
#endif
