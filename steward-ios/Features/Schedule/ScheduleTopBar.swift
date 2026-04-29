import SwiftUI
import StewardCore

#if canImport(FirebaseAuth)
/// The dark walnut top app bar that mirrors the web's `Eglinton Ward` shell:
/// brand mark + ward title + avatar menu. Solid background, not glass — the
/// web has a solid dark bar and so do we, leaving Liquid Glass for genuinely
/// floating chrome elsewhere.
struct ScheduleTopBar: View {
    let wardTitle: String
    let auth: AuthClient
    /// DEBUG-only callback wired up by `ScheduleView` so the avatar
    /// menu can push the Twilio plumbing debug screen onto the same
    /// nav stack. `nil` means the menu item is hidden.
    var onOpenTwilioDebug: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.s3) {
            BrandMark()
            Text(wardTitle)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.onAppBar)
                .lineLimit(1)
            Spacer(minLength: Spacing.s2)
            avatarMenu
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s2)
        .frame(maxWidth: .infinity)
        .background(Color.appBar.ignoresSafeArea(edges: .top))
    }

    private var avatarMenu: some View {
        Menu {
            if let email = auth.email {
                Text(email)
            }
            Divider()
            #if DEBUG
            if let onOpenTwilioDebug {
                Button("Twilio plumbing (debug)", systemImage: "ladybug", action: onOpenTwilioDebug)
                Divider()
            }
            #endif
            Button("Sign out", role: .destructive, action: auth.signOut)
        } label: {
            AvatarCircle(photoURL: auth.photoURL, displayName: auth.displayName, email: auth.email)
        }
        .accessibilityLabel("Account menu")
    }
}

private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(Color.bordeaux)
            Text("S")
                .font(.display(18, weight: .semibold))
                .foregroundStyle(Color.chalk)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

private struct AvatarCircle: View {
    let photoURL: URL?
    let displayName: String?
    let email: String?

    var body: some View {
        Group {
            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        initialsFallback
                    }
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(.circle)
        .overlay(Circle().stroke(Color.onAppBar.opacity(0.15), lineWidth: 0.5))
    }

    private var initialsFallback: some View {
        ZStack {
            Color.onAppBarMuted
            Text(initial)
                .font(.bodyEmphasis)
                .foregroundStyle(Color.appBar)
        }
    }

    private var initial: String {
        let source = displayName?.trimmingCharacters(in: .whitespaces) ?? email ?? ""
        return source.first.map { String($0).uppercased() } ?? "·"
    }
}

#Preview("Light") {
    ScheduleTopBar(wardTitle: "Eglinton Ward", auth: AuthClient())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ScheduleTopBar(wardTitle: "Eglinton Ward", auth: AuthClient())
        .preferredColorScheme(.dark)
}
#endif
