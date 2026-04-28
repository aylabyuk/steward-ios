import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)

// MARK: - Section header (sticky)

/// The pinned date strip at the top of each meeting card. Solid parchment
/// with a Liquid Glass effect over the content scrolling beneath. Mirrors
/// the web's `sticky top-0 z-10 bg-parchment/95 backdrop-blur-sm` strip.
struct MeetingCardHeader: View {
    let date: String
    let meeting: Meeting?
    let wardId: String

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
                    Button {
                        commitType(option.raw)
                    } label: {
                        // Native iOS Menu treats an empty systemImage as
                        // "no icon", so the active option gets a checkmark
                        // and the others stay flush-left. Mirrors the web's
                        // bordeaux-dot active marker without needing a
                        // custom row.
                        if option.raw == effectiveType {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
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
/// numbered speaker slots, plus OP/CP prayer rows. Owns the per-meeting
/// `CollectionSubscription<Speaker>` so each card lazily attaches its own
/// Firestore listener (matches the web's `useSpeakers(date)` pattern).
struct MeetingCardBody: View {
    let date: String
    let meeting: Meeting?
    let wardId: String
    /// Tapped on an empty slot's `Assign…` pill. The parent (ScheduleView)
    /// pushes onto the NavigationPath; this view stays Firebase-blind to
    /// the navigation mechanism.
    var onAssign: (SlotKind) -> Void = { _ in }

    /// Floor for visible speaker rows — the typical ward roster.
    /// Below this, empty rows render as `Assign Speaker` placeholders
    /// to invite the bishopric to fill them in.
    private static let minSpeakerSlots = 2

    /// Ceiling for visible speaker rows. Once the assigned count
    /// reaches this, the `Add another speaker` affordance disappears
    /// and the card stops growing.
    private static let maxSpeakerSlots = 4

    @State private var speakers: CollectionSubscription<Speaker>

    init(
        date: String,
        meeting: Meeting?,
        wardId: String,
        onAssign: @escaping (SlotKind) -> Void = { _ in }
    ) {
        self.date = date
        self.meeting = meeting
        self.wardId = wardId
        self.onAssign = onAssign
        let path = "wards/\(wardId)/meetings/\(date)/speakers"
        let source = FirestoreCollectionSource(path: path)
        self._speakers = State(initialValue: CollectionSubscription<Speaker>(
            source: source,
            decoder: { try JSONDecoder().decode(Speaker.self, from: $0) },
            path: path
        ))
    }

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
        return SlotRow(
            label: label,
            assignee: assignee,
            topic: assigned ? role : nil,
            status: assignment?.status,
            showStatus: assigned,
            assignKind: assigned ? nil : kind,
            onAssign: { onAssign(kind) }
        )
    }


    @ViewBuilder
    private var speakerRows: some View {
        let assignedCount = speakers.items.count
        let slots = Speaker.slots(speakers.items, minSlotCount: Self.minSpeakerSlots)
        ForEach(slots) { slot in
            SlotRow(
                label: slot.label,
                assignee: slot.speaker?.data.name,
                topic: slot.speaker?.data.topic,
                status: slot.speaker?.data.status,
                showStatus: slot.speaker != nil,
                assignKind: slot.speaker == nil ? .speaker : nil,
                onAssign: { onAssign(.speaker) }
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
/// status dot at the trailing edge. The dot replaces the older chat
/// affordance — chat isn't wired yet, so a dedicated indicator reads
/// more honestly than a no-op icon button.
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

    var body: some View {
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
                VStack(alignment: .leading, spacing: 2) {
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
#endif
