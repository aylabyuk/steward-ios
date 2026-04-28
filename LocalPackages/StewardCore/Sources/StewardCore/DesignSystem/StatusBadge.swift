import SwiftUI

/// 4-state status pill mirroring the web's `STATE_CLS` map at
/// `src/features/.../SpeakerRow.tsx`. One source of truth for the
/// background / foreground / border combination so meeting status, speaker
/// status, and prayer status all agree on what "confirmed" looks like.
public struct StatusBadge: View {
    public let label: String
    public let tone: Tone

    public init(label: String, tone: Tone) {
        self.label = label
        self.tone = tone
    }

    /// Build from the raw string status the backend stores. Unknown values
    /// (and `nil`) fall back to `.neutral` so the UI still renders something.
    public init(rawStatus: String?, label: String? = nil) {
        let resolvedTone = Tone(rawStatus: rawStatus)
        self.tone = resolvedTone
        self.label = label ?? (rawStatus?.replacingOccurrences(of: "_", with: " ") ?? "—")
    }

    public var body: some View {
        Text(label.uppercased())
            .font(.monoMicro)
            .tracking(1.2)
            .lineLimit(1)
            // Claim natural width and never wrap — long labels like
            // "General Conference" must stay on one line so every card
            // header strip is the same height.
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, 5)
            .foregroundStyle(tone.foreground)
            .background(tone.background, in: .capsule)
            .overlay(Capsule().stroke(tone.border, lineWidth: 1))
            .accessibilityLabel("Status: \(label)")
    }

    public enum Tone: Equatable, Sendable {
        /// `planned`, `draft`, unknown — sitting in the queue, no action yet.
        case neutral
        /// `invited`, `pending_approval` — awaiting a response.
        case pending
        /// `confirmed`, `approved`, `published` — locked in.
        case success
        /// `declined` — explicit no.
        case destructive

        public init(rawStatus: String?) {
            switch rawStatus?.lowercased() {
            case "invited", "pending_approval":
                self = .pending
            case "confirmed", "approved", "published":
                self = .success
            case "declined":
                self = .destructive
            case "planned", "draft", nil, "":
                self = .neutral
            default:
                self = .neutral
            }
        }

        public var foreground: Color {
            switch self {
            case .neutral: .walnut2
            case .pending: .brassDeep
            case .success: .success
            case .destructive: .bordeaux
            }
        }
        public var background: Color {
            switch self {
            case .neutral: .parchment2
            case .pending: .brassSoft
            case .success: .successSoft
            case .destructive: .dangerSoft
            }
        }
        public var border: Color {
            switch self {
            case .neutral: .border
            case .pending: .brassSoft
            case .success: .successSoft
            case .destructive: .dangerSoft
            }
        }
    }
}

#Preview("All tones, light + dark") {
    VStack(spacing: 12) {
        ForEach(["planned", "invited", "confirmed", "declined",
                 "draft", "pending_approval", "approved", "published"], id: \.self) { status in
            HStack {
                Text(status).font(.bodySmall).foregroundStyle(.secondary).frame(width: 160, alignment: .leading)
                StatusBadge(rawStatus: status)
            }
        }
    }
    .padding()
    .background(Color.parchment)
}
