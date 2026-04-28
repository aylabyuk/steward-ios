import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

/// Renders the bishopric's interpolated letter for the just-filled
/// `InvitationDraft`, then offers three terminal actions:
///   - **Save as Planned** — write the assignment with `status = planned`,
///     pop back to the schedule. The bishop can come back later to invite.
///   - **Share** — open `UIActivityViewController` with the rendered letter
///     as the share payload (Mail / Messages / WhatsApp / Print / Copy
///     are all wired by the system). Status is *not* flipped on share —
///     "Mark as Invited" is the explicit signal.
///   - **Mark as Invited** — write the assignment with
///     `status = invited`, pop back. Mirrors the web's "Mark invited
///     after print" affordance for the case when delivery happens
///     out-of-band (paper letter, in-person).
struct InvitationPreviewView: View {
    let draft: InvitationDraft
    @Binding var path: NavigationPath

    @State private var template: DocSubscription<LetterTemplate>
    @State private var saving: Bool = false
    @State private var saveError: String?

    init(draft: InvitationDraft, path: Binding<NavigationPath>) {
        self.draft = draft
        self._path = path
        self._template = State(initialValue: LetterTemplateSource.subscription(
            wardId: draft.wardId,
            kind: draft.kind
        ))
    }

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()
            content
        }
        .navigationTitle("Preview Invitation")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        if template.loading {
            ProgressView("Loading ward letter…")
                .controlSize(.large)
                .tint(Color.brassDeep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let template = template.data {
            letterView(template: template)
        } else if let error = template.error {
            errorState(message: "Couldn't load the ward's letter template — \(error.localizedDescription)")
        } else {
            errorState(message: "No \(draft.kind.isPrayer ? "prayer" : "speaker") letter template is set up for this ward yet. Configure one on the web before sending invitations.")
        }
    }

    private func letterView(template: LetterTemplate) -> some View {
        let rendered = render(template: template)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                AppBarHeader(
                    eyebrow: previewEyebrow,
                    title: draft.name,
                    description: previewDescription
                )

                VStack(alignment: .leading, spacing: Spacing.s4) {
                    markdownText(rendered.bodyMarkdown)
                    if rendered.footerMarkdown.isEmpty == false {
                        markdownText(rendered.footerMarkdown)
                            .padding(.top, Spacing.s4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
                .padding(.horizontal, Spacing.s4)

                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .font(.bodySmall)
                        .foregroundStyle(Color.bordeaux)
                        .padding(.horizontal, Spacing.s4)
                }

                actions(rendered: rendered)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.bottom, Spacing.s8)
            }
        }
    }

    private func actions(rendered: RenderedLetter) -> some View {
        VStack(spacing: Spacing.s3) {
            Button {
                Task { await commit(status: .invited) }
            } label: {
                Label("Mark as Invited", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.bordeaux)
            .controlSize(.large)
            .disabled(saving)

            ShareLink(
                item: rendered.plainText,
                subject: Text(shareSubject),
                message: Text(rendered.plainText)
            ) {
                Label("Share…", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.walnut)
            .controlSize(.large)
            .disabled(saving)

            Button {
                Task { await commit(status: .planned) }
            } label: {
                Text("Save as Planned")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.walnut2)
            .controlSize(.large)
            .disabled(saving)
        }
    }

    private func commit(status: InvitationStatus) async {
        saving = true
        saveError = nil
        defer { saving = false }
        do {
            switch draft.kind {
            case .speaker:
                _ = try await InvitationsClient.writeSpeaker(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    draft: draft,
                    status: status
                )
            case .openingPrayer, .benediction:
                try await InvitationsClient.writePrayerAssignment(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    kind: draft.kind,
                    draft: draft,
                    status: status
                )
            }
            popToRoot()
        } catch {
            saveError = "Couldn't save — \(error.localizedDescription)"
        }
    }

    private func popToRoot() {
        if path.count > 0 {
            path.removeLast(path.count)
        }
    }

    private func render(template: LetterTemplate) -> RenderedLetter {
        let vars = LetterInterpolator.variables(for: draft, today: Date())
        return RenderedLetter(
            bodyMarkdown: LetterInterpolator.interpolate(template.bodyMarkdown, vars: vars),
            footerMarkdown: LetterInterpolator.interpolate(template.footerMarkdown, vars: vars)
        )
    }

    @ViewBuilder
    private func markdownText(_ markdown: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.bodyDefault)
                .foregroundStyle(Color.walnut)
        } else {
            Text(markdown)
                .font(.bodyDefault)
                .foregroundStyle(Color.walnut)
        }
    }

    private var previewEyebrow: String {
        switch draft.kind {
        case .speaker:        "Speaker invitation"
        case .openingPrayer:  "Opening prayer invitation"
        case .benediction:    "Closing prayer invitation"
        }
    }

    private var previewDescription: String {
        let dateLabel = ShortDateFormatter.shortDate(fromISO8601: draft.meetingDate)
        return "For sacrament meeting — \(dateLabel)"
    }

    private var shareSubject: String {
        switch draft.kind {
        case .speaker:        "Sacrament meeting speaker invitation"
        case .openingPrayer,
             .benediction:    "Sacrament meeting prayer invitation"
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: Spacing.s4) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.bordeaux)
            Text(message)
                .font(.bodyDefault)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s8)

            Button {
                Task { await commit(status: .planned) }
            } label: {
                Text("Save as Planned anyway")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.walnut2)
            .controlSize(.large)
            .padding(.horizontal, Spacing.s8)

            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .font(.bodySmall)
                    .foregroundStyle(Color.bordeaux)
                    .padding(.horizontal, Spacing.s8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
