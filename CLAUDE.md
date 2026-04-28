# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

`steward-ios` is a **net-new SwiftUI port** of the Steward web app (a PWA used by ward bishoprics). At the time of writing, the Xcode project is the bare template — `steward_iosApp.swift` + `ContentView.swift` only. No SPM dependencies, no folder structure, no tests, no CI yet. We are at the start of the **Phase 0 spike** (started 2026-04-27).

The full implementation plan, phase breakdown, App Store compliance checklist, and CI/CD design lives at:

- `~/.claude/plans/pure-prancing-lecun.md` — the plan
- `~/.claude/projects/-Users-oriel-projects-steward-ios/memory/MEMORY.md` — auto-memory index (project overview, plan pointer, feedback memories)

**Read the plan before doing architectural work.** The CLAUDE.md only captures repo-level facts; the plan captures the cross-system context (web → iOS migration, Firebase backend reuse, Twilio Conversations REST/WebSocket strategy, Apple compliance gates).

## Building & running

This is a standard Xcode 26 app project, no workspace, no Pods, no SPM manifest yet (deps will be added through Xcode's package UI).

```sh
# Build for simulator
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests once a test target exists (none yet)
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Clean
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios clean
```

For day-to-day work, open `steward-ios.xcodeproj` in Xcode and use ⌘R / ⌘U.

## Project structure rules

The Xcode project uses **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16+ synced folders). The `steward-ios/` directory on disk *is* the source group — adding, moving, or deleting files in the filesystem auto-syncs into the build target. **Do not hand-edit `project.pbxproj` to add source files.** Just write the file to the right path on disk.

This makes the planned restructure (`App/ Features/ Core/ Models/ DesignSystem/` per the plan) a pure file-move operation; no project surgery required.

## Build settings worth knowing

These are set in `project.pbxproj` and shape how code should be written:

- **iOS deployment target: 26.4** — iOS 26 APIs (Liquid Glass, latest `@Observable`/SwiftData, etc.) are available unconditionally. No back-deployment shims needed.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — types and top-level code are `@MainActor` by default. Annotate explicitly with `nonisolated` / `actor` / a different global actor when work needs to run off the main thread (Firestore listeners, WebSocket consumers, image rendering, etc.).
- **`SWIFT_APPROACHABLE_CONCURRENCY = YES`** + **`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`** — the project opts into Swift 6-era concurrency diagnostics. Expect Sendable/isolation errors at compile time, fix them properly rather than suppressing.
- **Bundle ID: `ca.thevincistudios.steward-ios`**. (Note: the plan document still references `com.aylabyuk.steward` from an earlier draft — `project.pbxproj` is authoritative.)
- **Targeted device family: iPhone + iPad** (universal). Layouts must work in both regular and compact size classes.
- **Development team: `49AC3WCTNX`**, automatic code signing.

## Backend & local dev environment

The iOS app is a thin client over the existing Firebase backend used by the web app. The plan calls for development against the **Firebase emulator suite** during Phase 0 so contributors don't need a live project. Emulator setup lives in the web repo and is invoked with `firebase emulators:start` from there. There is no backend code in this repo and there should never be — Cloud Functions, Firestore rules, and Twilio integrations stay in the web repo.

The two web-repo files most worth reading before writing equivalent iOS code:

- `src/hooks/_sub.ts` — the `useDocSnapshot` / `useCollectionSnapshot` primitives. Lines 60–86 contain two subtleties (start `loading: true` until every path segment is non-empty; skip the `fromCache && !exists()` first-fire) that the iOS `FirestoreSubscription<T>` must mirror.
- `src/lib/types/` — nine Zod schemas that translate directly to Swift `Codable`. These are the source of truth for the data layer.

## Skills to use while writing code

The user has explicitly asked that we lean on the available `swiftui-*` and `swift-*` skills proactively rather than retrofitting. See the `feedback_use_swift_skills.md` auto-memory for the full cadence; the short version:

- Consult **swiftui-ui-patterns** and **swift-concurrency-pro** *as you write*.
- Run **swiftui-pro** after any non-trivial view; **swiftui-liquid-glass** for iOS 26 surfaces.
- Run **swift-security-expert** before merging anything that touches Keychain, OAuth tokens, FCM tokens, or Twilio JWTs.
- Run **swift-testing-pro** when writing tests; **simplify** after larger chunks.

## Conventions specific to this codebase

- **Don't reimplement server-side crypto.** Capability tokens, invitation hashing, and SMS bridging all stay in `functions/` on the web repo. iOS only invokes callables (`issueSpeakerSession`, `sendSpeakerInvitation`) and never sees plaintext secrets.
- **Lexical content is read-only on iOS** for v1. Authoring stays on the web. Any `letterTemplates` / `programTemplates` rendering walks the serialized Lexical JSON tree into `AttributedString` — it does not edit it.
- **Speaker-side flows stay on the web.** This iOS app is bishopric-only; there is no public-link / unauthenticated surface to build.
