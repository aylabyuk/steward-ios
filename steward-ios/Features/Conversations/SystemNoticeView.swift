import SwiftUI
import StewardCore

/// Centered status-change line ("Assignment confirmed — thank you for
/// speaking on Sun May 17."). Mirrors the web's `SystemNotice.tsx` —
/// rule | label | rule layout, green tint for confirmed, bordeaux for
/// declined. Drops out of the normal author/bubble flow because it's
/// a record-of-truth event, not a conversational message.
struct SystemNoticeView: View {
    let message: String
    /// `"confirmed"` or `"declined"`. Drives the rule + label colour.
    let status: String

    private var tint: Color {
        switch status {
        case "confirmed": return Color.success
        case "declined":  return Color.bordeaux
        default:          return Color.walnut2
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s2) {
            rule
            Text(message)
                .font(.serifAside)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            rule
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
    }

    private var rule: some View {
        Rectangle()
            .fill(tint.opacity(0.4))
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }
}
