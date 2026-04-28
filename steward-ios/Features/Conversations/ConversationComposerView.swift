import SwiftUI
import StewardCore

/// Bottom-of-sheet text composer + Send button. Mirrors the web's
/// `ConversationComposer.tsx` minus the SMS-segment hint (the web
/// shows it at 140+ chars; iOS doesn't dispatch SMS so it's not
/// load-bearing).
struct ConversationComposerView: View {
    let placeholder: String
    let isSending: Bool
    /// Called whenever the user types — observers fire
    /// `conversation.typing()` on this hook.
    var onTyping: () -> Void = {}
    let onSend: (String) async -> Void

    @State private var draft: String = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .bottom, spacing: Spacing.s3) {
                inputField
                sendButton
            }
            if let error {
                Text(error)
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .background(
            Color.parchment
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.border.opacity(0.5)).frame(height: 0.5)
                }
        )
    }

    private var inputField: some View {
        TextField(placeholder, text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .padding(.horizontal, Spacing.s3)
            .padding(.vertical, Spacing.s2 + 2)
            .background(
                Color.chalk,
                in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                    .stroke(Color.border, lineWidth: 0.5)
            )
            .focused($focused)
            .onChange(of: draft) { _, _ in onTyping() }
            .submitLabel(.send)
            .onSubmit { Task { await send() } }
    }

    /// Send button. iOS 26+ uses `.glassProminent` with a bordeaux
    /// tint — gives the system's native primary-action treatment
    /// while staying on-brand (the PWA renders a solid bordeaux pill;
    /// glass-prominent on a bordeaux tint reads as the same emphasis
    /// with iOS-native polish). Pre-iOS-26 falls back to a solid
    /// bordeaux-fill rounded rect that matches the PWA verbatim.
    @ViewBuilder
    private var sendButton: some View {
        if #available(iOS 26, *) {
            Button {
                Task { await send() }
            } label: {
                Text("Send")
                    .font(.bodyEmphasis)
                    .padding(.horizontal, Spacing.s3)
                    .padding(.vertical, Spacing.s2)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.bordeaux)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
            .accessibilityLabel("Send message")
        } else {
            Button {
                Task { await send() }
            } label: {
                Text("Send")
                    .font(.bodyEmphasis)
                    .foregroundStyle(Color.parchment)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s2 + 2)
                    .background(
                        Color.bordeaux,
                        in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .opacity(canSend ? 1 : 0.5)
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else { return }
        error = nil
        await onSend(body)
        draft = ""
    }
}
