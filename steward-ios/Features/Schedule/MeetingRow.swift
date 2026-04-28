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
            Button("View details") { /* future — push detail */ }
            Button("Edit") { /* future — push editor */ }
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

    /// Always render at least this many speaker rows so missing slots
    /// read as "Not assigned" placeholders rather than a short list.
    /// Mirrors `MobileSundayBody`'s `SPEAKER_SLOT_COUNT = 4`.
    private static let minSpeakerSlots = 4

    @State private var speakers: CollectionSubscription<Speaker>

    init(date: String, meeting: Meeting?, wardId: String) {
        self.date = date
        self.meeting = meeting
        self.wardId = wardId
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
            if effectiveIsTestimonyMeeting {
                testimonyNote
                slotDivider
            } else {
                speakerRows
            }
            prayerRow(label: "OP", role: "Invocation", assignee: meeting?.openingPrayerName)
            slotDivider
            prayerRow(label: "CP", role: "Benediction", assignee: meeting?.benedictionName)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
        .padding(.bottom, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.border).frame(height: 0.5)
        }
    }

    /// Prayer-giver row. Same shell as a speaker row, with the role label
    /// ("Invocation" / "Benediction") taking the topic slot. Chat button
    /// shows when the slot is assigned. Status is currently `nil` — the
    /// `openingPrayer` / `benediction` fields on the meeting doc carry
    /// only `confirmed: Bool?`, not the full invitation lifecycle. When
    /// prayers get promoted to the `prayers/{role}` subcollection
    /// (per the web schema), we can wire in the same `StatusBadge.Tone`
    /// mapping used for speakers.
    private func prayerRow(label: String, role: String, assignee: String?) -> some View {
        let assigned = assignee?.isEmpty == false
        return SlotRow(
            label: label,
            assignee: assignee,
            topic: assigned ? role : nil,
            status: nil,
            showStatus: false
        )
    }

    private var effectiveIsTestimonyMeeting: Bool {
        if let meeting { return meeting.isTestimonyMeeting }
        return Meeting.fallbackType(forDate: date) == "fast"
    }

    private var speakerRows: some View {
        let slots = Speaker.slots(speakers.items, minSlotCount: Self.minSpeakerSlots)
        return ForEach(slots) { slot in
            SlotRow(
                label: slot.label,
                assignee: slot.speaker?.data.name,
                topic: slot.speaker?.data.topic,
                status: slot.speaker?.data.status,
                showStatus: slot.speaker != nil
            )
            slotDivider
        }
    }

    private var testimonyNote: some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            Image(systemName: "star.circle")
                .font(.title3)
                .foregroundStyle(Color.brassDeep)
            VStack(alignment: .leading, spacing: 2) {
                Text("TESTIMONY MEETING")
                    .font(.monoEyebrow)
                    .tracking(1.4)
                    .foregroundStyle(Color.brassDeep)
                Text("No assigned speakers — member testimonies.")
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut2)
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
    /// Whether to render the trailing status dot. Speaker rows pass
    /// `true` (assigned speakers always have at least a "planned" status);
    /// prayer rows pass `false` for now since the meeting doc's inline
    /// `Assignment` doesn't carry the full lifecycle yet.
    var showStatus: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text(label)
                .font(.monoEyebrow)
                .tracking(1.2)
                .foregroundStyle(Color.brassDeep)
                .frame(width: 36, alignment: .leading)
                // Nudge the slot label down so it sits on the assignee
                // name's first baseline rather than the box top.
                .padding(.top, 4)

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
            } else {
                Text("Not assigned")
                    .font(.serifAside)
                    .foregroundStyle(Color.walnut3)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showStatus {
                StatusDot(status: status)
                    .padding(.trailing, Spacing.s2)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

/// Compact 8pt circle in the same `StatusBadge.Tone` palette used by
/// meeting-type badges, so the visual language stays consistent across
/// the schedule. VoiceOver label spells the status word out loud for
/// screen readers and color-blind accessibility.
private struct StatusDot: View {
    let status: String?

    var body: some View {
        let tone = StatusBadge.Tone(rawStatus: status)
        Circle()
            .fill(tone.foreground)
            .frame(width: 8, height: 8)
            .accessibilityLabel("Status: \(status ?? "planned")")
    }
}
#endif
