# Design resources

This file maps the web app's design system to the iOS DesignSystem module so
contributors don't have to reverse-engineer either side. The web is the source
of truth for the *brand* — cream parchment, walnut, brass, bordeaux serifs —
and iOS mirrors it with a typed Swift API plus a derived dark theme.

## Where things live

| Concern | Web file | iOS file |
|---|---|---|
| Color palette | `/Users/oriel/projects/steward/src/styles/index.css` (`@theme` block) | `LocalPackages/StewardCore/Sources/StewardCore/DesignSystem/Colors.swift` |
| Spacing scale | `index.css` (`--spacing-*`) | `…/DesignSystem/Spacing.swift` |
| Border radii | `index.css` (`--radius-*`) | `…/DesignSystem/Radii.swift` |
| Shadows | `index.css` (`--shadow-elev-*`) | `…/DesignSystem/Shadows.swift` |
| Typography | `index.css` (`@layer base`) + Google Fonts `<link>` in `index.html` | `…/DesignSystem/Fonts.swift` + `steward-ios/Resources/Fonts/*.ttf` |
| Status badge | `src/features/.../SpeakerRow.tsx` (`STATE_CLS`) and `src/features/invitations/utils/statusStripBg.ts` | `…/DesignSystem/StatusBadge.swift` |
| App-bar header | `src/components/ui/AppBar.tsx` (eyebrow + title + description hero) | `…/DesignSystem/AppBarHeader.swift` |
| Card surface | inline `rounded-lg border border-border bg-chalk p-6 shadow-sm` | `…/DesignSystem/CardSurface.swift` (`.cardSurface()` modifier) |

## Token quick reference

### Colors

The full hex map (light + dark variants) lives in `Colors.swift`. From SwiftUI:

```swift
import StewardCore

Text("Hello")
    .foregroundStyle(Color.walnut)        // primary text
    .background(Color.parchment)          // page background
    .background(Color.chalk)              // card surface
```

Brand axes:
- **Parchment** family — backgrounds (`.parchment`, `.parchment2`, `.parchment3`)
- **Walnut** family — text (`.walnut`, `.walnut2`, `.walnut3`, `.walnutInk`)
- **Bordeaux** family — primary CTA + destructive (`.bordeaux`, `.bordeauxDeep`, `.bordeauxSoft`)
- **Brass** family — accent + eyebrows (`.brass`, `.brassSoft`, `.brassDeep`)
- **Status** — `.success` / `.successSoft`, `.warning` / `.warningSoft`, `.dangerSoft`, `.infoSoft`

Each token resolves dynamically — `Color.walnut` is parchment-light text in dark mode automatically.

### Fonts

```swift
import StewardCore

Text("Steward").font(.displayHero)             // Newsreader 28pt semibold
Text("Sun, May 17").font(.displaySection)      // Newsreader 20pt semibold
Text("Bishop Smith").font(.bodyEmphasis)       // Inter 14pt semibold
Text("Conducting:").font(.monoEyebrow).tracking(1.6)  // IBM Plex Mono 10.5pt
```

Three families, all bundled at `steward-ios/Resources/Fonts/`:
- **Newsreader** (serif) — display headlines and italic asides
- **Inter Variable** (sans) — body copy
- **IBM Plex Mono** — eyebrow labels, status pills, slot numbers

PostScript family names verified at runtime via `FontAudit.dumpLoadedFonts()`
(in `steward-ios/App/FontAudit.swift`, DEBUG-only; logs to launch console at
app start). The OFL licenses are bundled at
`steward-ios/Resources/Fonts/LICENSES.md`.

### Status badge

Single component, four tones, derived from a string status:

```swift
import StewardCore

StatusBadge(rawStatus: meeting.status)         // auto-tones from "approved" etc.
StatusBadge(label: "Fast & Testimony", tone: .pending)
```

Status string → tone mapping (see `StatusBadge.Tone(rawStatus:)`):

| Status string | Tone | Web slot |
|---|---|---|
| `planned`, `draft`, `nil`, unknown | `.neutral` | parchment-2 / walnut-2 |
| `invited`, `pending_approval` | `.pending` | brass-soft / brass-deep |
| `confirmed`, `approved`, `published` | `.success` | success-soft / success |
| `declined` | `.destructive` | danger-soft / bordeaux |

### App-bar header

Use at the top of every feature screen for the eyebrow + display title +
italic-serif description hero:

```swift
AppBarHeader(
    eyebrow: "Ward administration",
    title: "Schedule",
    description: "Upcoming sacrament meetings."
)
```

`eyebrow` and `description` are optional. The component auto-applies the
right colors and fonts; don't override them per screen.

### Card surface

Apply to any container that should "lift" out of the parchment page:

```swift
VStack { … }
    .cardSurface()
    // = padding(24) + chalk fill + 1pt border + radius lg + elev1 shadow
```

## Screen inventory (current)

| Screen | iOS file | Used for |
|---|---|---|
| Login | `steward-ios/Features/Auth/LoginView.swift` | Continue-with-Google + Sign-in-with-Apple, debug bishop shortcut in emulator mode |
| Access required | `steward-ios/Features/Auth/AccessRequiredView.swift` | Signed-in user has no active member doc — show their email + sign-out CTA + "Hide My Email" hint when relevant |
| Ward picker | `steward-ios/Features/Auth/WardPickerView.swift` | Multi-ward member chooses which ward to operate on |
| Schedule | `steward-ios/Features/Schedule/ScheduleView.swift` | Live `wards/{wardId}/meetings` list, grouped by month, with sticky glass "Sign out" pill |
| Loading | inlined in `RootView.swift` | Brief between auth-resolved and ward-access-resolved (or while CurrentWard is being set from `.single`) |

Each screen uses the parchment background + AppBarHeader hero pattern
where applicable, and routes user actions through `AuthClient` /
`CurrentWard` / `WardAccessClient` rather than holding their own state.

## When to reach for Liquid Glass

iOS 26 ships native Liquid Glass — use it sparingly, where the web already
expresses the same idea via `backdrop-blur-sm` over a translucent background.

- ✅ **Floating toolbar buttons over scrolling content** (e.g. the "Sign out"
  pill in `ScheduleView`). The glass picks up the parchment underneath, which
  is what the web's `bg-parchment/85 backdrop-blur` is approximating.
- ✅ **Primary CTA on the login screen** — `.buttonStyle(.glassProminent)
  .tint(Color.bordeaux)` gives a warm tinted-glass effect that reads as the
  primary action without losing brand colour.
- ✅ **Debug shortcut button** — `.buttonStyle(.glass).tint(Color.brass)`
  for the dev-only "Sign in as bishop" affordance.
- ❌ **The card surface itself.** The web uses solid chalk, not a blurred
  pane; matching that intentionally keeps text readable and the card a clean
  container rather than a glassy artefact.
- ❌ **Body row chrome** (e.g. `MeetingRow`). Solid parchment, hairline
  borders. Don't add glass to dense list rows — it hurts legibility.

Modifier order: apply `.glassEffect(...)` after layout / appearance modifiers.
For multiple adjacent glass elements, wrap in `GlassEffectContainer` so they
blend instead of fighting each other.

## Adding a new feature

1. **Pick tokens before pixels.** Reach for `.walnut`, `.bordeaux`, `Spacing.s4`
   first; never `Color(red:..., green:..., blue:...)` or magic spacing numbers.
2. **Pick a `Font.*` preset.** If none fits, propose a new preset to add to
   `Fonts.swift` rather than calling `Font.custom(...)` inline.
3. **Reuse `StatusBadge` / `AppBarHeader` / `cardSurface`** before building a
   one-off chrome.
4. **Test the user-facing behaviour** in StewardCore (tone derivation, label
   formatting, grouping) — see CLAUDE.md "Test-driven development" + 
   `MeetingPresentationTests.swift` as a pattern.
5. **Verify both light + dark.** Wrap previews with
   `.preferredColorScheme(.light)` and `.preferredColorScheme(.dark)`.
   At the screen level, capture screenshots via
   `xcrun simctl ui booted appearance {light|dark}` + `screenshot`.

## Updating the design

If the web side updates a token (e.g. parchment shifts warmer):

1. Update `index.css` on the web (their job).
2. Update `Colors.swift` light-mode hex (our job — single source of truth here).
3. Re-derive the dark variant if the light shift was significant. Dark is
   *not* a mechanical inversion; it's a designed palette in its own right.
4. Run `swift test` from `LocalPackages/StewardCore/` — token-consuming tests
   should still pass; if any rely on specific colour values, update them too.
