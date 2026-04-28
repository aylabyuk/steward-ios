import SwiftUI
import StewardCore
import AuthenticationServices

#if canImport(FirebaseAuth)
struct LoginView: View {
    let auth: AuthClient
    @State private var isSubmitting: Bool = false
    /// Raw nonce stored across the Apple Sign-In request → callback round-trip.
    /// Apple's `appleCredential` initializer needs the un-hashed value to
    /// verify the returned identity token's `nonce` claim.
    @State private var currentAppleNonce: String?

    // DEBUG / emulator-only state for the dev-iteration shortcut.
    #if DEBUG
    @State private var debugEmail: String = ""
    @State private var debugPassword: String = ""
    #endif

    var body: some View {
        ZStack {
            Color.parchment2.ignoresSafeArea()

            VStack(spacing: Spacing.s6) {
                Spacer(minLength: Spacing.s8)
                heroLockup
                ssoCard
                #if DEBUG
                debugShortcut
                #endif
                Spacer()
            }
            .padding(.horizontal, Spacing.s5)
        }
        .task {
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

    private var ssoCard: some View {
        VStack(spacing: Spacing.s3) {
            googleButton
            appleButton
            errorBanner
        }
        .cardSurface()
    }

    private var googleButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: Spacing.s2) {
                if isSubmitting {
                    ProgressView().tint(Color.chalk)
                }
                Text(isSubmitting ? "Signing in…" : "Continue with Google")
                    .font(.bodyEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.bordeaux)
        .disabled(isSubmitting)
    }

    private var appleButton: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                let nonce = Nonce.random()
                self.currentAppleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Nonce.sha256(nonce)
            },
            onCompletion: handleAppleCompletion
        )
        .signInWithAppleButtonStyle(.black)  // `.whiteOutline` reads better in light cream — pick later
        .frame(height: 44)
        .clipShape(.rect(cornerRadius: Radius.lg))
        .disabled(isSubmitting)
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

    @ViewBuilder
    private var debugShortcut: some View {
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

    private func signInWithGoogle() {
        isSubmitting = true
        Task {
            await auth.signInWithGoogle()
            isSubmitting = false
        }
    }

    private func signInAsBishop() {
        isSubmitting = true
        Task {
            await auth.signIn(email: "bishop@e2e.local", password: "test1234")
            isSubmitting = false
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = appleCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = currentAppleNonce
            else {
                // Defensive: Apple didn't return what we asked for. Surface
                // a generic error rather than crashing.
                auth.recordError(NSError(
                    domain: "Steward.Auth", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Apple sign-in returned no identity token."]
                ))
                return
            }
            isSubmitting = true
            Task {
                await auth.signInWithApple(
                    idToken: idToken,
                    rawNonce: rawNonce,
                    fullName: appleCredential.fullName
                )
                currentAppleNonce = nil
                isSubmitting = false
            }
        case .failure(let error):
            // User cancellation reports as ASAuthorizationError.canceled —
            // don't show that as an error banner.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            auth.recordError(error)
        }
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
