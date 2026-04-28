---
name: log-deviation
description: |
  Append an entry to docs/web-deviations.md whenever you make an intentional
  iOS-side choice that diverges from the web PWA at /Users/oriel/projects/steward/.
  Trigger proactively after shipping a UI/UX/copy/behavior change on iOS that
  doesn't match the web's equivalent — different SwiftUI primitive (Menu vs
  bottom sheet), abbreviated copy, hidden/added rows, retuned interaction. Also
  invokable manually as /log-deviation when the user wants to capture one
  on demand. Skip for bug fixes, internal refactors, schema mappings under
  different syntax, or iOS-only features with no web equivalent — those
  aren't deviations.
---

# Log iOS ↔ PWA deviation

The web PWA at `/Users/oriel/projects/steward/` is the data-model source
of truth. iOS is allowed (and expected) to diverge when native idioms
read better — that convention is encoded in the project's `CLAUDE.md`.
This skill keeps a living ledger of those divergences in
`docs/web-deviations.md` so the team can later port iOS improvements
back to the PWA (or knowingly keep the divergence).

## When to invoke

Trigger this skill **proactively** whenever you finish a code change
that produces an intentional iOS-vs-PWA divergence:

- Picked a different SwiftUI primitive than the web (e.g. `Menu` vs.
  bottom sheet, `confirmationDialog` vs. modal, `Picker` vs. radio
  group).
- Abbreviated, rewrote, or shortened user-facing copy.
- Hid, reordered, or added UI elements vs. what the web shows.
- Retuned a behavior (persistent bar where web hides, no-op affordance
  where web routes, single contextual action where web splits two).
- Introduced a new design token because the web's would have read
  wrong (e.g. fixed-tone surface vs. theme-swapping token).

The user can also invoke manually with `/log-deviation` to capture
the most-recent design decision in conversation, even if you didn't
spot it as a deviation in the moment.

## When NOT to invoke

- **Bug fixes** that bring iOS back in line with intended behaviour.
  (e.g. fixing a bridging bug, an OAuth callback wiring, a font
  PostScript name typo.)
- **Internal refactors** with no user-facing diff.
- **iOS-only features** that have no web equivalent at all (those are
  net-new, not deviations).
- **Schema mappings** that are equivalent under different syntax
  (Codable mirroring a Zod schema, etc.).
- **Visual-token translations** where the goal is to *match* the web,
  not depart from it.

If unsure, it's better to log than to silently drift — the entry can
always be removed if the team decides the divergence wasn't real.

## Entry format

Append under the relevant feature `## Heading` (Schedule, Top app bar,
Speaker rows, etc.). Add a new `##` section before appending if the
feature isn't represented yet. Each entry has this shape:

```markdown
### <Short title — what differs>

**iOS**: <one or two sentences describing the iOS behaviour>.

**PWA**: <what the web does, with a relative path to the equivalent
web file when the diff is meaningful>.

**Why**: <the iOS-shape reason — native idiom, accessibility, layout
constraint, performance, etc.>.

**iOS code**: <relative path + symbol, so the team can find it
later>.
```

## How the skill executes

1. Read `docs/web-deviations.md`. Create it from the template at the
   top of the existing file if it's missing (intro + empty headings).
2. Identify the feature area for the deviation. If it doesn't have a
   `## Heading` yet, add one before the next horizontal rule.
3. Append the entry at the **bottom** of the relevant feature
   section (newest at the bottom — keeps git diffs readable).
4. If the user is currently committing or about to commit, fold the
   ledger update into the same commit so the deviation lands with the
   code that introduces it.

## Anti-patterns

- Don't log every visual tweak — only intentional divergences from
  the PWA's equivalent UX. Pure-iOS additions aren't deviations.
- Don't fork into a separate "deviations" PR. The ledger entry should
  ride with the code change.
- Don't paraphrase "the web does X but iOS does Y" without the
  **Why** — the reason is what makes the entry useful when the team
  later considers porting back.
