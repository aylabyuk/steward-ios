import SwiftUI
import StewardCore

/// Confirmation sheet for removing a speaker / prayer-giver whose
/// status is past `planned`. Requires the bishop to type the
/// assignee's name verbatim before the destructive button enables —
/// matches the "type the repo name to delete" pattern used by GitHub
/// and most ops surfaces, and prevents an accidental swipe-then-tap
/// from clearing a real commitment.
struct DeleteSpeakerConfirmationSheet: View {
    let speakerName: String
    let status: InvitationStatus
    let kind: SlotKind
    /// Fires when the bishop has typed the matching name and tapped
    /// the destructive button. The sheet dismisses itself
    /// immediately after — the parent only handles the actual
    /// Firestore write, not the presentation lifecycle.
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typedName: String = ""
    @FocusState private var nameFieldFocused: Bool

    private var canConfirm: Bool {
        typedName.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(speakerName) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    AppBarHeader(
                        eyebrow: removalEyebrow,
                        title: "Remove \(speakerName)?",
                        description: removalDescription
                    )

                    typedConfirmationField
                        .padding(.horizontal, Spacing.s4)

                    actions
                        .padding(.horizontal, Spacing.s4)
                        .padding(.bottom, Spacing.s8)
                }
            }
            .background(Color.parchment.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.walnut)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var removalEyebrow: String {
        switch kind {
        case .speaker:        return "Remove speaker"
        case .openingPrayer:  return "Remove opening prayer"
        case .benediction:    return "Remove closing prayer"
        }
    }

    private var removalDescription: String {
        let role: String = {
            switch kind {
            case .speaker:                       return "speaker"
            case .openingPrayer, .benediction:   return "prayer giver"
            }
        }()
        switch status {
        case .invited:
            return "\(speakerName) has been invited but hasn't responded yet. Removing them clears the assignment from Sunday's program. The conversation history stays in the record, but they'll no longer appear on the schedule."
        case .confirmed:
            return "\(speakerName) has confirmed the assignment. Removing them takes a confirmed \(role) off Sunday's program — make sure you've already followed up with them outside the app."
        case .declined:
            return "\(speakerName) declined the invitation. Removing them clears the row so you can assign someone else; the response stays in the record."
        case .planned:
            // Planned rows don't open this sheet, but render a sane
            // body anyway in case the entry point ever changes.
            return "Removing \(speakerName) clears the row from Sunday's program."
        }
    }

    private var typedConfirmationField: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("To confirm, type the name below.")
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
            TextField(speakerName, text: $typedName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s2 + 2)
                .background(
                    Color.chalk,
                    in: RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.default, style: .continuous)
                        .stroke(canConfirm ? Color.bordeaux : Color.border, lineWidth: 0.5)
                )
                .focused($nameFieldFocused)
                .onAppear { nameFieldFocused = true }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.s2) {
            Button(role: .destructive) {
                onConfirm()
                dismiss()
            } label: {
                Text("Remove \(speakerName)")
                    .font(.bodyEmphasis)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bordeaux)
            .controlSize(.large)
            .disabled(!canConfirm)
            .opacity(canConfirm ? 1 : 0.5)
            .accessibilityHint("Permanently removes \(speakerName) from Sunday's program.")
        }
    }
}
