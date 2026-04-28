import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
struct LoginView: View {
    let auth: AuthClient
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            header
            credentials
            signInButton
            debugBishopShortcut
            errorBanner
            Spacer()
        }
        .padding(.horizontal, 24)
        .task(id: autoSignInFlag) {
            // Debug helper for the simulator demo: launching with
            // SIMCTL_CHILD_AUTO_SIGNIN_BISHOP=1 signs in as the seeded bishop
            // immediately. No production code path uses this.
            if autoSignInFlag {
                signInAsBishop()
            }
        }
    }

    private var autoSignInFlag: Bool {
        #if DEBUG
        EmulatorConfig.isEnabled
            && ProcessInfo.processInfo.environment["AUTO_SIGNIN_BISHOP"] == "1"
        #else
        false
        #endif
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Steward")
                .font(.largeTitle.weight(.semibold))
            Text("Bishopric tools")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var credentials: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(12)
                .background(.fill.tertiary, in: .rect(cornerRadius: 10))
        }
    }

    private var signInButton: some View {
        Button(action: signIn) {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(isSubmitting ? "Signing in…" : "Sign in")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
    }

    @ViewBuilder
    private var debugBishopShortcut: some View {
        #if DEBUG
        if EmulatorConfig.isEnabled {
            Divider().padding(.vertical, 8)
            VStack(spacing: 8) {
                Text("Debug — emulator only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Sign in as bishop@e2e.local", action: signInAsBishop)
                    .buttonStyle(.bordered)
                    .disabled(isSubmitting)
            }
        }
        #endif
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = auth.lastError {
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private func signIn() {
        submit(email: email, password: password)
    }

    private func signInAsBishop() {
        submit(email: "bishop@e2e.local", password: "test1234")
    }

    private func submit(email: String, password: String) {
        isSubmitting = true
        Task {
            await auth.signIn(email: email, password: password)
            isSubmitting = false
        }
    }
}

#Preview {
    LoginView(auth: AuthClient())
}
#endif
