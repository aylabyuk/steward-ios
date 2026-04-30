import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// One form for speakers + prayer-givers. Conditional fields are driven
/// by `context.kind`: speakers see Topic + Role pickers, prayers don't
/// (their role is implicit from the slot they tapped). Validation
/// mirrors the web's lenient Zod — name required, email valid-or-empty,
/// phone free-form.
///
/// On `Continue`, builds an `InvitationDraft` and pushes it onto the
/// schedule's `NavigationPath`; `InvitationPreviewView` picks it up via
/// `.navigationDestination(for: InvitationDraft.self)`.
struct AssignSlotFormView: View {
    let context: SlotContext
    @Binding var path: NavigationPath

    @State private var name: String = ""
    @State private var topic: String = ""
    @State private var role: SpeakerRole = .member
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var validationError: InvitationDraft.ValidationError?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, topic, email, phone
    }

    var body: some View {
        Form {
            Section {
                TextField("Full name", text: $name)
                    .focused($focusedField, equals: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = nextFocus(after: .name) }
            } header: {
                Text("Name").font(.monoEyebrow).tracking(1.2)
            }

            if context.kind == .speaker {
                Section {
                    TextField("e.g. Faith, Service (optional)", text: $topic)
                        .focused($focusedField, equals: .topic)
                        .submitLabel(.next)
                        .onSubmit { focusedField = nextFocus(after: .topic) }
                } header: {
                    Text("Topic").font(.monoEyebrow).tracking(1.2)
                } footer: {
                    Text("Leave blank if you'd like the speaker to choose their own topic.")
                        .font(.serifAside)
                        .foregroundStyle(Color.walnut2)
                }

                Section {
                    Picker("Role", selection: $role) {
                        ForEach(SpeakerRole.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Role").font(.monoEyebrow).tracking(1.2)
                }
            }

            Section {
                TextField("name@example.com", text: $email)
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = nextFocus(after: .email) }

                TextField("Phone (optional)", text: $phone)
                    .focused($focusedField, equals: .phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            } header: {
                Text("Invitation reach").font(.monoEyebrow).tracking(1.2)
            } footer: {
                Text("We'll use these to compose the invitation. Leave blank if you plan to deliver it in person — you can come back to fill them in later.")
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut2)
            }

            if let validationError {
                Section {
                    Label(message(for: validationError), systemImage: "exclamationmark.triangle.fill")
                        .font(.bodySmall)
                        .foregroundStyle(Color.bordeaux)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle(context.kind.formTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Continue", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.bordeaux)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { focusedField = .name }
    }

    private func submit() {
        let draft = InvitationDraft(
            kind: context.kind,
            wardId: context.wardId,
            meetingDate: context.meetingDate,
            wardName: context.wardName,
            inviterName: context.inviterName,
            name: name,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            topic: topic.isEmpty ? nil : topic,
            role: context.kind == .speaker ? role : nil
        )
        switch draft.validate() {
        case .success(let validated):
            validationError = nil
            path.append(validated)
        case .failure(let error):
            validationError = error
        }
    }

    private func message(for error: InvitationDraft.ValidationError) -> String {
        switch error {
        case .nameRequired:  "A name is required to continue."
        case .invalidEmail:  "That email doesn't look right. Use the standard name@example.com format."
        case .roleRequired:  "Pick a role for the speaker."
        }
    }

    private func nextFocus(after field: Field) -> Field? {
        switch field {
        case .name:   context.kind == .speaker ? .topic : .email
        case .topic:  .email
        case .email:  .phone
        case .phone:  nil
        }
    }
}
#endif
