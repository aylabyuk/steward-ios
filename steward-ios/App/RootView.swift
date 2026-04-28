import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
struct RootView: View {
    @State private var auth = AuthClient()
    @State private var currentWard = CurrentWard()
    @State private var wardAccess = WardAccessClient(source: nil)

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView(auth: auth)
            } else {
                routeForAccess(wardAccess.state)
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .onChange(of: auth.email) { _, newEmail in
            rewireWardAccess(for: newEmail)
        }
        .onChange(of: wardAccess.state) { _, state in
            currentWard.resolve(from: state)
        }
        .onAppear {
            rewireWardAccess(for: auth.email)
        }
    }

    @ViewBuilder
    private func routeForAccess(_ state: WardAccess) -> some View {
        switch state {
        case .checking:
            loadingView
        case .none:
            AccessRequiredView(auth: auth)
        case .single:
            scheduleOrLoading
        case .multiple(let members):
            if let wardId = currentWard.wardId {
                ScheduleView(auth: auth, wardId: wardId)
                    .id(wardId)
            } else {
                WardPickerView(auth: auth, currentWard: currentWard, members: members)
            }
        }
    }

    @ViewBuilder
    private var scheduleOrLoading: some View {
        if let wardId = currentWard.wardId {
            ScheduleView(auth: auth, wardId: wardId)
                .id(wardId)
        } else {
            // `.single(_)` resolves CurrentWard via .onChange of state, but
            // there's a one-tick window before that fires; render the
            // loading state instead of crashing on a nil wardId.
            loadingView
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()
            VStack(spacing: Spacing.s3) {
                ProgressView()
                Text("Checking ward access…")
                    .font(.bodySmall)
                    .foregroundStyle(Color.walnut2)
            }
        }
    }

    private func rewireWardAccess(for email: String?) {
        let source: (any SnapshotSource<CollectionSnap>)?
        if let email, email.isEmpty == false {
            source = MemberAccessSource(email: email)
        } else {
            source = nil
            // Email cleared (sign-out) — also clear the schedule scope so
            // any in-flight Firestore listeners tear down.
            currentWard.clear()
        }
        wardAccess = WardAccessClient(source: source)
    }
}

#Preview {
    RootView()
}
#else
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
