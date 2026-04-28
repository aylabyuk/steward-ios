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

### Sunday-type lock — disabled rows + footer-button rationale, not a banner

**iOS**: When the meeting has at least one `confirmed` speaker, the
Sunday-Type radio group disables every option except the active one
and appends a final disabled menu item reading "Locked — remove
confirmed speakers to change." with the warning-triangle SF Symbol.
`commitType` also early-returns on locked taps as belt-and-braces.

**PWA**: Same lock rule, but the disabled options sit above a styled
banner (border-top, mono-uppercase, bordeaux warning icon) inside the
mobile bottom sheet (`SundayMenuOptions.tsx:58-77`).

**Why**: Native iOS `Menu` doesn't render Section footers, so the web
banner has no direct counterpart. A disabled `Button` with a warning
icon is the closest in-Menu rationale row — same role, just compact
enough for a popup. The Menu primitive overall is a stronger fit than
a custom bottom sheet for ≤8 grouped options (see the existing
"native iOS Menu, not bottom sheet" deviation above).

**iOS code**: `steward-ios/Features/Schedule/MeetingRow.swift` —
`MeetingCardHeader.overflowMenu` + `commitType`. The
`hasConfirmedSpeaker` flag flows in from
`MeetingCardSection`, which owns the per-card
`CollectionSubscription<Speaker>` and computes the predicate via
`Speaker.hasConfirmed(_:)` in
`LocalPackages/StewardCore/Sources/StewardCore/Speaker.swift`.

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

**iOS**: OP / CP rows show "Invocation" / "Closing Prayer" in italic
serif beneath the assignee's name (mirrors the speaker-row's
topic line).

**PWA**: Prayer rows show only the role label and assignee name on
one line (`PrayerRow.tsx`).

**Why**: Same row shell as the speaker row keeps the card visually
consistent. The "Invocation" / "Closing Prayer" caption tells the
bishop what they're looking at without a separate column.

**iOS code**: `steward-ios/Features/Schedule/MeetingRow.swift` —
`MeetingCardBody.prayerRow(...)`.

### Empty slots are tappable Assign… pills, not inert "Not assigned" text

**iOS**: An empty speaker / prayer slot renders an "Assign Speaker",
"Assign Opening Prayer", or "Assign Closing Prayer" pill (parchment-2
fill, brass plus icon, walnut text). Tapping pushes the new
single-person Assign-and-Invite flow.

**PWA**: Empty rows in the speaker list are silent; assignment
happens through the multi-step Plan Speakers / Plan Prayers wizard
launched from the menu (`features/plan-speakers/`,
`features/plan-prayers/`).

**Why**: Pairs with the per-row flow below — once tapping a row is
the way to assign, the row itself needs to *read* as the invitation
to act. Italic "Not assigned" text was inert; the pill makes the
verb visible without competing with filled assignees.

**iOS code**: `steward-ios/Features/Invitations/AssignSlotButton.swift`
— `AssignSlotButton`. Wired in
`steward-ios/Features/Schedule/MeetingRow.swift` — `SlotRow`.

---

## Assign + Invite

### Per-row Assign + Invite flow replaces the bulk Plan Speakers / Plan Prayers wizard

**iOS**: Tap an empty slot's `Assign…` pill → push
`AssignSlotFormView` (one form for speakers + prayers, conditional
on slot kind) → tap Continue → push `InvitationPreviewView` with
the interpolated ward letter → terminal CTAs of `Mark as Invited`,
`Share…`, or `Save as Planned`. One slot at a time.

**PWA**: Multi-step wizard
(`features/plan-speakers/RosterStep.tsx` →
`PreviewStep.tsx` → `SendStep.tsx`, mirrored on the prayer side
in `features/plan-prayers/`) processes a whole sacrament meeting's
roster in a single sitting.

**Why**: A bishop touching the schedule on their phone is usually
filling in a single slot they just got an answer for, not authoring
a whole roster. A focused, push-style flow per slot reads more
naturally on a phone than a multi-stage wizard. The wizard
authoring experience stays on the web.

**iOS code**:
`steward-ios/Features/Invitations/AssignSlotFormView.swift`,
`InvitationPreviewView.swift`,
`steward-ios/Core/Firestore/InvitationsClient.swift`.

### Share-sheet + explicit Mark-as-Invited, not auto-flip on send

**iOS**: The Preview screen offers `Share…` (system
`ShareLink` — Mail / Messages / WhatsApp / Print / Copy all
included automatically) and a separate `Mark as Invited` button.
Sharing does **not** flip status — only the explicit button does.

**PWA**: `sendSpeakerInvitation` Cloud Function sends via Twilio +
SendGrid and atomically flips status to `invited` on success
(`features/plan-speakers/hooks/useWizardActions.ts`). The "Mark
invited after print" affordance is the web's only manual flip.

**Why**: v1 of the iOS feature delivers via the system share sheet
rather than calling the Cloud Function. The share sheet doesn't
report whether the bishop actually sent the invitation in the
chosen app, so auto-flipping on share-sheet dismiss would lie about
state. A separate explicit button is the honest signal — and it
also reuses the web's "Mark invited after print" idiom for
out-of-band delivery (paper letter, in-person ask). Wire the Cloud
callable later when the iOS auto-send path lands.

**iOS code**:
`steward-ios/Features/Invitations/InvitationPreviewView.swift` —
`actions(rendered:)` and `commit(status:)`.

### Inline prayer-status field on `Meeting.Assignment`

**iOS**: The inline `meeting.openingPrayer` / `meeting.benediction`
Assignment now carries an optional `status: String?` alongside
`{person, confirmed}`. The schedule row reads from this field for
its status dot.

**PWA**: `assignmentSchema` (`src/lib/types/person.ts:10-14`)
defines only `{person, confirmed}` inline. Prayer status lives
exclusively on the post-invite `prayers/{role}` subcollection doc
that the bulk wizard creates. Web's lenient Zod silently ignores
extra fields it doesn't know about.

**Why**: To avoid building a parallel `prayers/{role}` writer + a
dual-source-of-truth read path in v1, iOS writes status straight
onto the inline Assignment. Same write path serves both planned
and invited prayers. When the iOS prayer surface grows past
invitations (RSVPs, chat, response tracking), promote to the
subcollection model the web uses.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/Meeting.swift` —
`Meeting.Assignment.status`. Write helper at
`steward-ios/Core/Firestore/InvitationsClient.swift` —
`writePrayerAssignment(...)`.

### Letter preview renders Markdown only — Lexical JSON ignored

**iOS**: `LetterTemplate` decodes both
`bodyMarkdown`/`footerMarkdown` and `editorStateJson` (Lexical),
but the preview only renders the Markdown via
`AttributedString(markdown:)`.

**PWA**: The web is migrating from Markdown → Lexical and
dual-writes both fields (`src/lib/types/template.ts:85-107`).
Authoring + send paths render the Lexical editor state when
present and fall back to Markdown.

**Why**: Implementing a Lexical-JSON-tree → SwiftUI renderer is a
much larger surface than v1 of this feature warrants — and the web
still dual-writes Markdown for compatibility. Targeting Markdown
keeps iOS readable for the foreseeable future. Promote when the
web stops dual-writing or when iOS gains a letter-template editor
of its own.

**iOS code**:
`LocalPackages/StewardCore/Sources/StewardCore/Invitations/LetterTemplate.swift`,
rendered in
`steward-ios/Features/Invitations/InvitationPreviewView.swift`.

### "Mark as Invited" calls `sendSpeakerInvitation` — web's same label is out-of-band

**iOS**: Tapping "Mark as Invited" on the invitation preview screen
calls `FunctionsClient.sendSpeakerInvitation(...)` with `channels: []`,
which mints a real `speakerInvitations/{id}` doc + Twilio Conversation +
bishopric participant snapshot, then flips `speaker.status` to invited
and stamps `invitationId`. No email/SMS is dispatched (channels empty).

**PWA**: The same label (`markInvited`) is a direct `updateSpeaker({
status: "invited" })` write — no callable, no Twilio conversation. It's
the out-of-band path for when the bishop already delivered the letter
by print/email/in-person. The web's "Send" / "Send SMS" buttons are the
ones that call `sendSpeakerInvitation`.

**Why**: iOS needed a way to mint invitations without first wiring a
full multi-button send UI (and the SendGrid/Twilio dispatch confirmation
flow). Hijacking "Mark as Invited" gives iOS-created assignments a real
Twilio conversation immediately — without it, the chat sheet would only
work for invitations originally sent from the web. Promote when iOS
gains real "Send via Email" / "Send via SMS" buttons.

**iOS code**:
`steward-ios/Features/Invitations/InvitationPreviewView.swift` —
`commitMarkInvited(rendered:)`. Callable wrapper at
`steward-ios/Core/Firebase/FunctionsClient.swift`.

### Chat is a navigation push, not a bottom drawer

**iOS**: Tapping a speaker / prayer name on the schedule pushes
`ConversationView` onto the existing `NavigationStack(path:)` —
standard iOS chevron-back, slide-in transition, system nav bar
with the speaker's name as inline title.

**PWA**: A `vaul`-driven drawer that slides up from the bottom on
mobile and from the right edge on desktop. Drag-to-dismiss; the
schedule peeks behind the partial-height drawer.

**Why**: Every native iOS messaging app (Messages, WhatsApp,
Slack) treats a conversation as a destination, not a transient
sheet. The keyboard handles much better in a navigation push than
on a sheet, the schedule-context-behind-it benefit didn't pay off
on phone-sized screens, and pushing matches the rest of the
codebase's `NavigationStack(path:)`-only convention (same as
`AssignSlotFormView` and `InvitationPreviewView`). System back
button replaces the PWA's explicit "CLOSE" text button — also no
"..." overflow icon yet (no actions wired).

**iOS code**:
`steward-ios/Features/Conversations/ConversationView.swift`,
pushed via `.navigationDestination(for: ChatPresentation.self)`
in `steward-ios/Features/Schedule/ScheduleView.swift`.
