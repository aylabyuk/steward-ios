import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
/// Shown when the signed-in member belongs to multiple wards. They pick
/// one, the picker writes the chosen wardId into `CurrentWard`, and
/// `RootView` falls through to `ScheduleView` with the resolved scope.
struct WardPickerView: View {
    let auth: AuthClient
    let currentWard: CurrentWard
    let members: [MemberAccess]

    var body: some View {
        ZStack {
            Color.parchment2.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.s5) {
                    AppBarHeader(
                        eyebrow: "Choose a ward",
                        title: "Where today?",
                        description: "You belong to multiple wards. Pick the one you'd like to work on."
                    )
                    VStack(spacing: Spacing.s3) {
                        ForEach(members) { member in
                            wardButton(for: member)
                        }
                    }
                    .padding(.horizontal, Spacing.s5)

                    Button("Sign out", action: auth.signOut)
                        .buttonStyle(.glass)
                        .tint(Color.walnut2)
                        .padding(.top, Spacing.s4)

                    Spacer(minLength: Spacing.s8)
                }
            }
        }
    }

    private func wardButton(for member: MemberAccess) -> some View {
        Button {
            currentWard.choose(member.wardId)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                HStack {
                    Text(member.wardId)
                        .font(.displaySection)
                        .foregroundStyle(Color.walnut)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(Color.walnut3)
                }
                if let role = member.role {
                    Text(role.uppercased())
                        .font(.monoMicro)
                        .tracking(1.2)
                        .foregroundStyle(Color.brassDeep)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}

#Preview("Light · two wards") {
    WardPickerView(
        auth: AuthClient(),
        currentWard: CurrentWard(),
        members: [
            MemberAccess(wardId: "stv1", uid: "u1", role: "bishopric", displayName: "Bishop Smith"),
            MemberAccess(wardId: "stv2", uid: "u1", role: "clerk", displayName: nil)
        ]
    )
    .preferredColorScheme(.light)
}
#endif
