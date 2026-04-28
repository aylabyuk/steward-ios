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
///   - **Mark as Invited** — call the `sendSpeakerInvitation` callable
///     (Cloud Function) which mints the `speakerInvitations/{id}` doc,
///     creates the Twilio Conversation, and snapshots the bishopric
///     roster as participants. We pass `channels: []` so no email/SMS
///     is dispatched — the bishop has already shared the letter out of
///     band. Then flip `speaker.status` (or the inline prayer
///     assignment) to `invited` and pop. **iOS-side deviation**: the
///     web's "Mark Invited" is a direct status flip with no Twilio
///     conversation; iOS hijacks the same label to mint a real
///     conversation so the chat sheet works for iOS-created assignments.
///     Logged in `docs/web-deviations.md`.
struct InvitationPreviewView: View {
    let draft: InvitationDraft
    let auth: AuthClient
    @Binding var path: NavigationPath

    @State private var template: DocSubscription<LetterTemplate>
    @State private var saving: Bool = false
    @State private var saveError: String?

    init(draft: InvitationDraft, auth: AuthClient, path: Binding<NavigationPath>) {
        self.draft = draft
        self.auth = auth
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
                Task { await commitMarkInvited(rendered: rendered) }
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
                Task { await commitPlanned() }
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

    /// Save-as-planned path: a single Firestore write, no callable, no
    /// Twilio conversation. The bishop can come back later and tap
    /// "Mark as Invited" to mint the conversation when they're ready.
    private func commitPlanned() async {
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
                    status: .planned
                )
            case .openingPrayer, .benediction:
                try await InvitationsClient.writePrayerAssignment(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    kind: draft.kind,
                    draft: draft,
                    status: .planned
                )
            }
            popToRoot()
        } catch {
            saveError = "Couldn't save — \(error.localizedDescription)"
        }
    }

    /// Mark-as-invited path: writes the assignment doc as planned, calls
    /// `sendSpeakerInvitation` (which mints the speakerInvitations doc +
    /// Twilio Conversation + bishopric participant snapshot) with
    /// `channels: []` so no email/SMS goes out, then flips status to
    /// invited and stamps the `invitationId`. If the callable fails after
    /// the planned doc is written, the bishop sees the row in the
    /// schedule as planned and can retry.
    private func commitMarkInvited(rendered: RenderedLetter) async {
        saving = true
        saveError = nil
        defer { saving = false }
        do {
            let bishopEmail = auth.email ?? ""
            let assignedDate = LetterInterpolator.fullSundayDate(draft.meetingDate)
            let sentOn = LetterInterpolator.longDate(Date())
            let expiresAtMillis = SendSpeakerInvitationRequest.computeExpiresAt(
                meetingDate: draft.meetingDate
            )

            switch draft.kind {
            case .speaker:
                let speakerId = try await InvitationsClient.writeSpeaker(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    draft: draft,
                    status: .planned
                )
                let req = SendSpeakerInvitationRequest.fresh(
                    draft: draft,
                    speakerId: speakerId,
                    channels: [],
                    bodyMarkdown: rendered.bodyMarkdown,
                    footerMarkdown: rendered.footerMarkdown,
                    sentOn: sentOn,
                    assignedDate: assignedDate,
                    bishopReplyToEmail: bishopEmail,
                    expiresAtMillis: expiresAtMillis
                )
                let res = try await FunctionsClient.sendSpeakerInvitation(req)
                try await InvitationsClient.updateSpeakerStatus(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    speakerId: speakerId,
                    status: .invited,
                    invitationId: res.invitationId
                )
            case .openingPrayer, .benediction:
                try await InvitationsClient.writePrayerAssignment(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    kind: draft.kind,
                    draft: draft,
                    status: .planned
                )
                let req = SendSpeakerInvitationRequest.fresh(
                    draft: draft,
                    speakerId: prayerRoleString(),
                    channels: [],
                    bodyMarkdown: rendered.bodyMarkdown,
                    footerMarkdown: rendered.footerMarkdown,
                    sentOn: sentOn,
                    assignedDate: assignedDate,
                    bishopReplyToEmail: bishopEmail,
                    expiresAtMillis: expiresAtMillis
                )
                let res = try await FunctionsClient.sendSpeakerInvitation(req)
                try await InvitationsClient.updatePrayerAssignmentStatus(
                    wardId: draft.wardId,
                    meetingDate: draft.meetingDate,
                    kind: draft.kind,
                    status: .invited,
                    invitationId: res.invitationId
                )
            }
            popToRoot()
        } catch {
            saveError = "Couldn't mark as invited — \(error.localizedDescription)"
        }
    }

    private func prayerRoleString() -> String {
        switch draft.kind {
        case .speaker:        return ""
        case .openingPrayer:  return "opening"
        case .benediction:    return "benediction"
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
                Task { await commitPlanned() }
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
