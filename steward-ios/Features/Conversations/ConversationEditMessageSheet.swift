import SwiftUI
import StewardCore

/// Edit-message sheet — a TextField pre-filled with the bubble's
/// current body, Save / Cancel toolbar buttons. Mirrors the web's
/// `BubbleActions.tsx` long-press → modal, just rendered as an iOS
/// sheet for native feel + cleaner keyboard handling.
///
/// Decision logic (trim / no-op-on-unchanged / blank-rejection)
/// lives in `EditMessageIntent.normalize(...)` so the sheet stays
/// dumb. Save fires the closure with the original message + the
/// proposed body; the parent runs `normalize` and decides whether
/// to actually write.
struct ConversationEditMessageSheet: View {
    let message: ChatMessage
    /// Fires when the bishop taps Save. Parent owns the dismissal +
    /// the Twilio write decision.
    let onSave: (ChatMessage, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @FocusState private var fieldFocused: Bool

    init(message: ChatMessage, onSave: @escaping (ChatMessage, String) -> Void) {
        self.message = message
        self.onSave = onSave
        _draft = State(initialValue: message.body)
    }

    private var canSave: Bool {
        EditMessageIntent.normalize(currentBody: message.body, proposedBody: draft) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("EDIT MESSAGE")
                        .font(.monoEyebrow)
                        .tracking(1.4)
                        .foregroundStyle(Color.brassDeep)
                    TextField("Message", text: $draft, axis: .vertical)
                        .font(.bodyDefault)
                        .foregroundStyle(Color.walnut)
                        .lineLimit(3...12)
                        .padding(Spacing.s3)
                        .background(
                            Color.chalk,
                            in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                                .stroke(Color.border, lineWidth: 0.5)
                        )
                        .focused($fieldFocused)
                        .submitLabel(.done)
                    Text("Edits show up immediately on the speaker's side. The bubble will be marked \"Edited.\"")
                        .font(.serifAside)
                        .foregroundStyle(Color.walnut3)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s4)
            }
            .background(Color.parchment.ignoresSafeArea())
            .navigationTitle("Edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.walnut)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(message, draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .tint(Color.bordeaux)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { fieldFocused = true }
    }
}
