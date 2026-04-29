import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

// MARK: - Section wrapper (owns per-card speaker subscription)

/// One Section in the schedule's pinned-headers stack. Owns the per-card
/// `CollectionSubscription<Speaker>` and forwards `speakers` to both the
/// header (for the Sunday-Type lock) and the body (for the speaker
/// rows). Returning a `Section` directly from this view's body keeps it
/// participating in `LazyVStack(pinnedViews: [.sectionHeaders])` — the
/// container's pinning logic walks through wrapping Views and finds the
/// Section all the same.
struct MeetingCardSection: View {
    let date: String
    let meeting: Meeting?
    let wardId: String
    var onAssign: (SlotKind) -> Void = { _ in }
    var onOpenChat: ((ChatPresentation) -> Void)? = nil
    var onRequestDelete: ((PendingDelete) -> Void)? = nil

    @State private var speakers: CollectionSubscription<Speaker>

    init(
        date: String,
        meeting: Meeting?,
        wardId: String,
        onAssign: @escaping (SlotKind) -> Void = { _ in },
        onOpenChat: ((ChatPresentation) -> Void)? = nil,
        onRequestDelete: ((PendingDelete) -> Void)? = nil
    ) {
        self.date = date
        self.meeting = meeting
        self.wardId = wardId
        self.onAssign = onAssign
        self.onOpenChat = onOpenChat
        self.onRequestDelete = onRequestDelete
        let path = "wards/\(wardId)/meetings/\(date)/speakers"
        let source = FirestoreCollectionSource(path: path)
        self._speakers = State(initialValue: CollectionSubscription<Speaker>(
            source: source,
            decoder: { try JSONDecoder().decode(Speaker.self, from: $0) },
            path: path
        ))
    }

    var body: some View {
        Section {
            MeetingCardBody(
                date: date,
                meeting: meeting,
                wardId: wardId,
                speakers: speakers,
                onAssign: onAssign,
                onOpenChat: onOpenChat,
                onRequestDelete: onRequestDelete
            )
        } header: {
            MeetingCardHeader(
                date: date,
                meeting: meeting,
                wardId: wardId,
                hasConfirmedSpeaker: Speaker.hasConfirmed(speakers.items)
            )
        }
    }
}

// MARK: - Section header (sticky)

/// The pinned date strip at the top of each meeting card. Solid parchment
/// with a Liquid Glass effect over the content scrolling beneath. Mirrors
/// the web's `sticky top-0 z-10 bg-parchment/95 backdrop-blur-sm` strip.
struct MeetingCardHeader: View {
    let date: String
    let meeting: Meeting?
    let wardId: String
    /// Drives the Sunday-Type menu lock. When `true`, only the active
    /// type row stays tappable and a "Locked — remove confirmed
    /// speakers to change." footer appears beneath the radio group.
    var hasConfirmedSpeaker: Bool = false

    /// Injected for previews / tests. Production callers leave the default.
    var today: Date = Date()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text(ShortDateFormatter.monthDay(fromISO8601: date))
                    .font(.displaySection)
                    .foregroundStyle(Color.walnut)

                if let pill = RelativeDayLabel.string(fromISO8601: date, today: today) {
                    Text(pill.uppercased())
                        .font(.monoEyebrow)
                        .tracking(1.4)
                        .foregroundStyle(Color.brassDeep)
                }
            }
            Spacer(minLength: Spacing.s2)
            if let badge = effectiveTypeBadge {
                StatusBadge(label: badge.label, tone: badge.tone)
            }
            overflowMenu
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.border).frame(height: 0.5)
        }
    }

    private var effectiveTypeBadge: (label: String, tone: StatusBadge.Tone)? {
        if let meeting { return meeting.typeBadge }
        return Meeting(meetingType: Meeting.fallbackType(forDate: date)).typeBadge
    }

    private var overflowMenu: some View {
        Menu {
            Section {
                Button(action: planAction) {
                    Label(
                        Meeting.planActionLabel(meeting: meeting),
                        systemImage: meeting == nil ? "calendar.badge.plus" : "list.bullet.clipboard"
                    )
                }
            }
            Section("Sunday Type") {
                ForEach(SundayTypeOption.all) { option in
                    let isActive = option.raw == effectiveType
                    Button {
                        commitType(option.raw)
                    } label: {
                        // Native iOS Menu treats an empty systemImage as
                        // "no icon", so the active option gets a checkmark
                        // and the others stay flush-left. Mirrors the web's
                        // bordeaux-dot active marker without needing a
                        // custom row.
                        if isActive {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                    .disabled(hasConfirmedSpeaker && !isActive)
                }
                if hasConfirmedSpeaker {
                    // iOS-side equivalent of the web's "LOCKED — REMOVE
                    // CONFIRMED SPEAKERS TO CHANGE." footer. Native
                    // `Menu` doesn't render Section footers, so a
                    // disabled Button with the warning icon serves as
                    // the rationale row — same role as the web banner,
                    // just compact enough for a popup menu. See
                    // docs/web-deviations.md.
                    Button {
                        // Inert; the disabled state is the affordance.
                    } label: {
                        Label(
                            "Locked — remove confirmed speakers to change.",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                    .disabled(true)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.walnut3)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .accessibilityLabel("Meeting actions")
    }

    /// The currently-active type — from the doc when one exists, else the
    /// inferred fallback (first-Sunday-of-month → fast, otherwise regular).
    /// Drives which menu row gets the checkmark.
    private var effectiveType: String {
        meeting?.meetingType ?? Meeting.fallbackType(forDate: date)
    }

    private func planAction() {
        // Future — push to the planning view. The destination decides
        // whether to render the "start" or "view" experience based on
        // the meeting doc state, mirroring the label logic above.
    }

    private func commitType(_ type: String) {
        guard type != effectiveType else { return }
        // Belt-and-braces against a stale tap landing while a confirmed
        // speaker exists — the Menu disables the row, but a listener
        // refresh between render and tap shouldn't slip a write through.
        guard hasConfirmedSpeaker == false else { return }
        Task {
            do {
                try await MeetingsClient.setMeetingType(wardId: wardId, date: date, type: type)
            } catch {
                // TODO: surface a toast / inline error once we have a
                // shared UI affordance for save failures. Silent failures
                // are OK in Phase 0 — the user sees the unchanged
                // checkmark when the listener re-fires.
            }
        }
    }
}

// MARK: - Section body

/// The scrolling body of a meeting card — testimony note (fast Sundays) or
/// numbered speaker slots, plus OP/CP prayer rows. Receives the per-card
/// `CollectionSubscription<Speaker>` from `MeetingCardSection`, which
/// owns the listener so the header can read `hasConfirmedSpeaker` from
/// the same source. @Observable propagation through this `let` keeps
/// the body in sync as Firestore re-emits.
struct MeetingCardBody: View {
    let date: String
    let meeting: Meeting?
    let wardId: String
    let speakers: CollectionSubscription<Speaker>
    /// Tapped on an empty slot's `Assign…` pill. The parent (ScheduleView)
    /// pushes onto the NavigationPath; this view stays Firebase-blind to
    /// the navigation mechanism.
    var onAssign: (SlotKind) -> Void = { _ in }
    /// Tapped on a filled slot's name. The parent (ScheduleView)
    /// presents `ConversationSheet` for the chat. nil disables the
    /// tap target — used by previews / unit-test snapshots.
    var onOpenChat: ((ChatPresentation) -> Void)? = nil
    /// Fires when the user taps the swipe-revealed Remove button on
    /// a filled row. The parent decides what to do: planned rows
    /// delete straight through, non-planned rows go through the
    /// type-name-to-confirm sheet.
    var onRequestDelete: ((PendingDelete) -> Void)? = nil

    /// Floor for visible speaker rows — the typical ward roster.
    /// Below this, empty rows render as `Assign Speaker` placeholders
    /// to invite the bishopric to fill them in.
    private static let minSpeakerSlots = 2

    /// Ceiling for visible speaker rows. Once the assigned count
    /// reaches this, the `Add another speaker` affordance disappears
    /// and the card stops growing.
    private static let maxSpeakerSlots = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if effectiveKind.isSpecial {
                specialStamp(kind: effectiveKind)
                if effectiveKind.hasLocalProgram {
                    slotDivider
                }
            } else {
                speakerRows
            }
            if effectiveKind.hasLocalProgram {
                prayerRow(
                    label: "OP",
                    role: "Invocation",
                    assignment: meeting?.openingPrayer,
                    kind: .openingPrayer
                )
                slotDivider
                prayerRow(
                    label: "CP",
                    role: "Closing Prayer",
                    assignment: meeting?.benediction,
                    kind: .benediction
                )
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.border).frame(height: 0.5)
        }
    }

    /// The card's effective `MeetingKind` — driven by the doc's
    /// `meetingType` when present, otherwise inferred from the date
    /// (first Sunday of the month → fast).
    private var effectiveKind: MeetingKind {
        let raw = meeting?.meetingType ?? Meeting.fallbackType(forDate: date)
        return MeetingKind(rawType: raw)
    }

    /// Prayer-giver row. Same shell as a speaker row, with the role label
    /// ("Invocation" / "Closing Prayer") taking the topic slot. Status comes
    /// from the inline `Meeting.Assignment.status` field — an iOS-side
    /// deviation from the web schema that lets us flip planned →
    /// invited without standing up the `prayers/{role}` subcollection
    /// in this PR. See `docs/web-deviations.md`.
    private func prayerRow(
        label: String,
        role: String,
        assignment: Meeting.Assignment?,
        kind: SlotKind
    ) -> some View {
        let assignee = assignment?.person?.name
        let assigned = assignee?.isEmpty == false
        let chatHandler: (() -> Void)? = {
            guard assigned, let assignment, let onOpenChat else { return nil }
            guard let presentation = ChatPresentation.forPrayer(
                meetingDate: date,
                kind: kind,
                assignment: assignment
            ) else { return nil }
            return { onOpenChat(presentation) }
        }()
        let deleteHandler: (() -> Void)? = {
            guard assigned,
                  let assignment,
                  let person = assignment.person,
                  let name = person.name, name.isEmpty == false,
                  let role = kind.prayerRoleString,
                  let onRequestDelete else { return nil }
            let pending = PendingDelete(
                kind: kind,
                meetingDate: date,
                speakerId: role,
                speakerName: name,
                status: InvitationStatus(rawString: assignment.status) ?? .planned
            )
            return { onRequestDelete(pending) }
        }()
        return SlotRow(
            label: label,
            assignee: assignee,
            topic: assigned ? role : nil,
            status: assignment?.status,
            showStatus: assigned,
            assignKind: assigned ? nil : kind,
            onAssign: { onAssign(kind) },
            onChat: chatHandler,
            onDelete: deleteHandler
        )
    }


    private func speakerChatHandler(for slot: SpeakerSlot) -> (() -> Void)? {
        guard let speakerItem = slot.speaker, let onOpenChat else { return nil }
        let presentation = ChatPresentation(
            kind: .speaker,
            meetingDate: date,
            speakerId: speakerItem.id,
            speaker: speakerItem.data
        )
        return { onOpenChat(presentation) }
    }

    private func speakerDeleteHandler(for slot: SpeakerSlot) -> (() -> Void)? {
        guard let speakerItem = slot.speaker, let onRequestDelete else { return nil }
        let pending = PendingDelete(
            kind: .speaker,
            meetingDate: date,
            speakerId: speakerItem.id,
            speakerName: speakerItem.data.name,
            status: InvitationStatus(rawString: speakerItem.data.status) ?? .planned
        )
        return { onRequestDelete(pending) }
    }

    @ViewBuilder
    private var speakerRows: some View {
        let assignedCount = speakers.items.count
        let slots = Speaker.slots(speakers.items, minSlotCount: Self.minSpeakerSlots)
        ForEach(slots) { slot in
            SlotRow(
                label: slot.label,
                assignee: slot.speaker?.data.name,
                topic: slot.speaker?.data.displayTopic,
                status: slot.speaker?.data.status,
                showStatus: slot.speaker != nil,
                assignKind: slot.speaker == nil ? .speaker : nil,
                onAssign: { onAssign(.speaker) },
                onChat: speakerChatHandler(for: slot),
                onDelete: speakerDeleteHandler(for: slot)
            )
            slotDivider
        }
        if Speaker.canAddMore(
            assignedCount: assignedCount,
            floor: Self.minSpeakerSlots,
            ceiling: Self.maxSpeakerSlots
        ) {
            addSpeakerRow
        }
    }

    /// Explicit "+ Add another speaker" affordance below the last
    /// filled row. Indented to align with the assignee-name column on
    /// the rows above so the row rhythm stays — no slot number, since
    /// this is an action, not a slot. Routes through the same
    /// `onAssign(.speaker)` closure as the placeholder pills, so a
    /// new speaker doc is written on the bishop's next save with no
    /// extra ordering bookkeeping.
    private var addSpeakerRow: some View {
        HStack(spacing: Spacing.s3) {
            // Match the slot label column width (36) + its leading +
            // trailing gutters so the button's leading edge sits where
            // an assignee name would.
            Color.clear.frame(width: 36)
            AssignSlotButton(
                kind: .speaker,
                label: "Add another speaker"
            ) {
                onAssign(.speaker)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.s2)
    }

    /// Centered "stamp" rendered in place of the speaker list for fast,
    /// stake, and general Sundays. Shape matches the web's
    /// `SundayCardSpecial` (icon + uppercased label + italic-serif
    /// description). Tone follows `MeetingKind.stampTone` so fast reads
    /// brass and stake/general read bordeaux.
    @ViewBuilder
    private func specialStamp(kind: MeetingKind) -> some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            // Same 36pt leading column the slot-label uses, so the star
            // icon's leading edge sits where the "01" / "OP" labels do
            // and the title/description column lines up with assignee
            // names on the rows above.
            Image(systemName: "star.circle")
                .font(.title3)
                .foregroundStyle(kind.stampTone.foreground)
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if let label = kind.stampLabel {
                    Text(label.uppercased())
                        .font(.monoEyebrow)
                        .tracking(1.4)
                        .foregroundStyle(kind.stampTone.foreground)
                }
                if let description = kind.stampDescription {
                    Text(description)
                        .font(.serifAside)
                        .foregroundStyle(Color.walnut2)
                }
            }
        }
        .padding(.vertical, Spacing.s3)
    }

    private var slotDivider: some View {
        Rectangle()
            .fill(Color.border.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

// MARK: - Slot row

/// One assignment row inside a meeting card. Renders the slot label
/// ("01", "OP", "CP") on the left, the assignee's name (with optional
/// italic-serif topic / role label underneath, mirroring `SpeakerRow.tsx`)
/// or an italic "Not assigned" placeholder, and a compact colored
/// status dot at the trailing edge. Filled rows wrap the
/// assignee+topic block in a tap target — tapping opens the
/// `ConversationSheet` (Phase 2 chat sheet).
private struct SlotRow: View {
    let label: String
    let assignee: String?
    var topic: String? = nil
    var status: String? = nil
    /// Whether to render the trailing status dot. Filled speaker /
    /// prayer rows pass `true`; empty rows don't need a dot — the
    /// `Assign…` pill carries the affordance instead.
    var showStatus: Bool = false
    /// Drives the empty-slot CTA. `nil` falls back to the legacy inert
    /// "Not assigned" text — which is unreachable from the schedule
    /// today, but keeps the row defensive for previews / unit-test
    /// snapshots.
    var assignKind: SlotKind? = nil
    var onAssign: () -> Void = {}
    /// Tap target on the assignee name — opens the chat sheet. nil
    /// disables the tap (used for previews / unit-test snapshots).
    var onChat: (() -> Void)? = nil
    /// Left-swipe-revealed remove action. nil disables the swipe (used
    /// for empty rows + previews). Filled rows always pass this; the
    /// parent decides whether to confirm-then-delete or delete
    /// straight through based on status.
    var onDelete: (() -> Void)? = nil

    var body: some View {
        if let onDelete {
            SwipeToDeleteRow(onDelete: onDelete) {
                rowContent
            }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        // Center-aligned so the slot label, assignee block, and status
        // dot all vertically center to the row's content height —
        // looks balanced whether the row has a single line ("Not
        // assigned" / pill / one-line speaker) or two (name + topic).
        HStack(alignment: .center, spacing: Spacing.s3) {
            Text(label)
                .font(.monoEyebrow)
                .tracking(1.2)
                .foregroundStyle(Color.brassDeep)
                .frame(width: 36, alignment: .leading)

            if let assignee, assignee.isEmpty == false {
                let block = VStack(alignment: .leading, spacing: 2) {
                    Text(assignee)
                        .font(.bodyEmphasis)
                        .foregroundStyle(Color.walnut)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let topic, topic.trimmingCharacters(in: .whitespaces).isEmpty == false {
                        Text(topic)
                            .font(.serifAside)
                            .foregroundStyle(Color.walnut2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                if let onChat {
                    Button(action: onChat) { block }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open conversation with \(assignee)")
                } else {
                    block
                }
            } else if let assignKind {
                AssignSlotButton(kind: assignKind, action: onAssign)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Not assigned")
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showStatus {
                StatusDot(status: status)
                    .padding(.trailing, Spacing.s2)
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

/// Compact status indicator in the schedule's `StatusBadge.Tone`
/// palette, sized 10pt so each state reads at a glance. Shape and
/// colour both vary by state — relying on colour alone would fail
/// `.accessibilityDifferentiateWithoutColor` and read as
/// indistinguishable to colour-blind users:
///
///   - **planned** — hollow ring (chalk fill, walnut-2 stroke).
///     Communicates "no action yet, awaiting plan".
///   - **invited** — solid brass dot. The default "filled" state,
///     awaiting a response.
///   - **confirmed** — solid `successBold` dot, punchier than the
///     muted brand olive used in `StatusBadge`'s body.
///   - **declined** — solid `bordeauxBold` dot, punchier than the
///     muted brand bordeaux used in `StatusBadge`'s body.
///
/// VoiceOver still reads the raw status word so screen-reader users
/// don't depend on the shape distinction either.
private struct StatusDot: View {
    let status: String?

    private static let size: CGFloat = 10

    var body: some View {
        let tone = StatusBadge.Tone(rawStatus: status)
        Group {
            switch tone {
            case .neutral:
                // Planned — hollow ring, the empty look.
                Circle()
                    .fill(Color.chalk)
                    .overlay(Circle().stroke(Color.walnut2, lineWidth: 1.5))
            case .pending:
                // Invited — solid brass dot.
                Circle().fill(Color.brassDeep)
            case .success:
                // Confirmed — punchier green.
                Circle().fill(Color.successBold)
            case .destructive:
                // Declined — punchier red.
                Circle().fill(Color.bordeauxBold)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityLabel("Status: \(status ?? "planned")")
    }
}

private extension SlotKind {
    /// Prayer participant doc id for the subcollection. Nil for
    /// speakers, which have their own auto-generated ids.
    var prayerRoleString: String? {
        switch self {
        case .speaker:        return nil
        case .openingPrayer:  return "opening"
        case .benediction:    return "benediction"
        }
    }
}
#endif
