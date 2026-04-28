import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
struct LoginView: View {
    let auth: AuthClient
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        ZStack {
            Color.parchment2.ignoresSafeArea()

            VStack(spacing: Spacing.s6) {
                Spacer(minLength: Spacing.s8)
                heroLockup
                loginCard
                #if DEBUG
                debugBishopShortcut
                #endif
                Spacer()
            }
            .padding(.horizontal, Spacing.s5)
        }
        .task {
            // Debug helper: launching with SIMCTL_CHILD_AUTO_SIGNIN_BISHOP=1
            // signs in as the seeded bishop immediately so simctl-driven
            // demos skip the empty form.
            #if DEBUG
            if EmulatorConfig.isEnabled,
               ProcessInfo.processInfo.environment["AUTO_SIGNIN_BISHOP"] == "1" {
                signInAsBishop()
            }
            #endif
        }
    }

    private var heroLockup: some View {
        VStack(spacing: Spacing.s2) {
            Text("BISHOPRIC TOOLS")
                .font(.monoEyebrow)
                .tracking(1.6)
                .foregroundStyle(Color.brassDeep)
            Text("Steward")
                .font(.displayLogin)
                .foregroundStyle(Color.walnut)
            Text("Sign in with the account linked to your ward.")
                .font(.serifAside)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, Spacing.s2)
    }

    private var loginCard: some View {
        VStack(spacing: Spacing.s3) {
            credentials
            errorBanner
            signInButton
        }
        .cardSurface()
    }

    private var credentials: some View {
        VStack(spacing: Spacing.s3) {
            FieldShell {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            FieldShell {
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
        }
    }

    private var signInButton: some View {
        Button(action: signIn) {
            HStack {
                if isSubmitting {
                    ProgressView().tint(Color.chalk)
                }
                Text(isSubmitting ? "Signing in…" : "Sign in")
                    .font(.bodyEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.bordeaux)
        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
    }

    @ViewBuilder
    private var debugBishopShortcut: some View {
        if EmulatorConfig.isEnabled {
            VStack(spacing: Spacing.s2) {
                Text("DEBUG · EMULATOR ONLY")
                    .font(.monoMicro)
                    .tracking(1.2)
                    .foregroundStyle(Color.walnut3)
                Button("Sign in as bishop@e2e.local", action: signInAsBishop)
                    .buttonStyle(.glass)
                    .tint(Color.brass)
                    .disabled(isSubmitting)
            }
            .padding(.top, Spacing.s2)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = auth.lastError {
            Text(error.localizedDescription)
                .font(.bodySmall)
                .foregroundStyle(Color.bordeaux)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.s3)
                .background(Color.dangerSoft, in: .rect(cornerRadius: Radius.default))
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

/// Tailored field shell mirroring the web's
/// `rounded-md border border-border bg-chalk px-2 py-1`.
private struct FieldShell<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .font(.bodyDefault)
            .foregroundStyle(Color.walnut)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s3)
            .background(Color.chalk, in: .rect(cornerRadius: Radius.default))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.default)
                    .stroke(Color.border, lineWidth: 1)
            )
    }
}

#Preview("Light") {
    LoginView(auth: AuthClient())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LoginView(auth: AuthClient())
        .preferredColorScheme(.dark)
}
#endif
