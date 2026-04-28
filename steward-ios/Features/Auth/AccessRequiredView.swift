import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
/// Shown when the user is signed in but has no active member doc in any
/// ward. Mirrors the web's `AccessRequired.tsx` — display the email they
/// used (so they can verify they signed in with the right account), an
/// instruction to contact the bishopric, and a Sign-out CTA so they
/// can try again with a different account.
struct AccessRequiredView: View {
    let auth: AuthClient

    var body: some View {
        ZStack {
            Color.parchment2.ignoresSafeArea()

            VStack(spacing: Spacing.s6) {
                Spacer(minLength: Spacing.s8)
                heroLockup
                messageCard
                signOutButton
                Spacer()
            }
            .padding(.horizontal, Spacing.s5)
        }
    }

    private var heroLockup: some View {
        VStack(spacing: Spacing.s2) {
            Text("ACCESS REQUIRED")
                .font(.monoEyebrow)
                .tracking(1.6)
                .foregroundStyle(Color.brassDeep)
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(Color.bordeaux)
                .padding(.vertical, Spacing.s2)
            Text("You're signed in, but not yet a member of any ward.")
                .font(.displaySection)
                .foregroundStyle(Color.walnut)
                .multilineTextAlignment(.center)
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            if let email = auth.email {
                HStack {
                    Text("SIGNED IN AS")
                        .font(.monoMicro)
                        .tracking(1.2)
                        .foregroundStyle(Color.walnut3)
                    Spacer()
                    Text(email)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.walnut)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Text("Ask the bishopric to add this email to your ward roster, then sign in again.")
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.leading)
            if let email = auth.email, isAppleRelay(email: email) {
                Text("Tip: Apple's “Hide My Email” gives a private relay address that the bishopric can't recognise. Sign in again with “Share My Email” selected so we get your real address.")
                    .font(.bodySmall)
                    .foregroundStyle(Color.brassDeep)
                    .padding(Spacing.s3)
                    .background(Color.brassSoft, in: .rect(cornerRadius: Radius.default))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var signOutButton: some View {
        Button("Sign out and try a different account", action: auth.signOut)
            .buttonStyle(.glass)
            .tint(Color.walnut)
    }

    private func isAppleRelay(email: String) -> Bool {
        email.hasSuffix("@privaterelay.appleid.com")
    }
}

#Preview("Light · regular email") {
    AccessRequiredView(auth: AuthClient())
        .preferredColorScheme(.light)
}
#endif
