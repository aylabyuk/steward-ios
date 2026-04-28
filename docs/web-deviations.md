# iOS ↔ PWA deviations

Living ledger of where the iOS app's UI/UX intentionally differs from the
web PWA at `/Users/oriel/projects/steward/`. The PWA is the data-model
source of truth, but iOS deviates when native idioms read better. Use
this list when porting iOS improvements back to the PWA — each entry
captures *what* differs, *why* iOS chose to, and *where* the iOS code
lives so the diff is easy to mirror.

Deviations are appended automatically by the `log-deviation` skill
(`.claude/skills/log-deviation/`). When you intentionally diverge from
the PWA in iOS code, an entry should land here in the same commit.

---

## Schedule

### Sunday-type selector — native iOS Menu, not bottom sheet

**iOS**: Tap ⋯ on a meeting card → inline `Menu` with `Section`s pops
out. Section 1: Plan/View action. Section 2: Sunday-Type radio group
(checkmark on active option).

**PWA**: `MobileBottomSheet` drawer with the same content
(`SundayTypeMenu.tsx`).

**Why**: Native iOS `Menu` is a strong primitive for ≤8 grouped
options — free dismiss-on-outside-tap, keyboard / VoiceOver, dark-mode
handling. Bottom sheets feel heavy when the content is just buttons
and radios. We'd reach for a sheet only when content grows past ~10
items or needs forms.

**iOS code**: `steward-ios/Features/Schedule/MeetingRow.swift` —
`MeetingCardHeader.overflowMenu`.

### Stake/General Conference — no OP/CP rows

**iOS**: Stake and General Conference cards collapse to just the
"No local program" stamp. Prayer rows are hidden.

**PWA**: `SundayCardSpecial.tsx` still renders OP/CP `PrayerRow`s
beneath the stamp.

**Why**: Stake-wide / general-wide sessions don't have local prayer
assignments, so the empty "Not assigned" rows just confused the
bishop. The stamp alone communicates "no local program" cleanly.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/MeetingKind.swift` —
`hasLocalProgram`.

### Stake/General badge — abbreviated to one line

**iOS**: Header badge reads `Stake Conf.` / `General Conf.`

**PWA**: Badge reads `Stake Conference` / `General Conference`.

**Why**: Full names pushed the date headline (`May 24`) onto two
lines on phone widths. The body stamp still spells the full name, so
the header badge is just a quick marker.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/Meeting.swift` —
`Meeting.typeBadge`.

### Plan-action label — "Plan / View Meeting" pair

**iOS**: Menu's first row reads `Plan Sacrament Meeting` when the
meeting doc doesn't exist, `View Meeting` once it does.

**PWA**: Plan actions are two separate links: `Plan speakers` and
`Plan prayers` (`SundayMenuPlanActions.tsx`).

**Why**: One contextual entry is shorter than two static links and
matches the "doc exists vs. not" discriminator the iOS card already
has. Web's two-action split assumes a richer per-entity flow that
hasn't shipped on iOS yet.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/Meeting.swift` —
`Meeting.planActionLabel`.

---

## Top app bar

### Always visible — no hide-on-scroll

**iOS**: The dark "Eglinton Ward" bar stays pinned at the top of the
screen at all times.

**PWA**: Header scrolls with content (it's part of the page).

**Why**: We tried hide-on-scroll, but the iOS status bar sat against
the parchment page background with no chrome behind it, which looked
unfinished. The system-handled fix requires a `NavigationStack`
(deferred to Phase 1 when detail/edit pushes land); revisit then.

**iOS code**: `steward-ios/Features/Schedule/ScheduleView.swift`.

### Fixed-dark surface — doesn't swap in Dark mode

**iOS**: `Color.appBar` resolves to dark walnut in both light and dark
mode (slightly deeper hex in dark for contrast against the dark
parchment page).

**PWA**: Light-mode only.

**Why**: The `walnut` text token swaps to cream in dark mode, which
would have made the bar an unreadable cream surface with cream text
in the dark theme. A fixed-dark token preserves the brand's "always
a high-contrast bar above the parchment page" intent.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/DesignSystem/Colors.swift`
— `appBar` / `onAppBar` / `onAppBarMuted`.

---

## Speaker rows

### Status conveyed by colored dot, not text pill

**iOS**: 8pt circle at the trailing edge of each speaker row, tinted
with `StatusBadge.Tone.foreground` (planned=walnut-2, invited=brass,
confirmed=success-green, declined=bordeaux). VoiceOver label reads
`Status: <status>`.

**PWA**: Full text pill (`INVITED`, `PLANNED`, etc.), ~80pt wide.

**Why**: Phone width is tight; ~70pt extra room for the speaker name
+ italic-serif topic was worth more than spelling out the status
word. The dot reuses the same colour palette as the meeting-type
badge so the visual language stays unified.

**iOS code**: `steward-ios/Features/Schedule/MeetingRow.swift` —
`SlotRow` + `StatusDot`.

### Prayer rows show role label as subtitle

**iOS**: OP / CP rows show "Invocation" / "Benediction" in italic
serif beneath the assignee's name (mirrors the speaker-row's
topic line).

**PWA**: Prayer rows show only the role label and assignee name on
one line (`PrayerRow.tsx`).

**Why**: Same row shell as the speaker row keeps the card visually
consistent. The "Invocation" / "Benediction" caption tells the
bishop what they're looking at without a separate column.

**iOS code**: `steward-ios/Features/Schedule/MeetingRow.swift` —
`MeetingCardBody.prayerRow(...)`.
