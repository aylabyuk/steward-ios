# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

`steward-ios` is a **net-new SwiftUI port** of the Steward web app (a PWA used by ward bishoprics). Phase 0 spike is in progress (started 2026-04-27). The folder layout has been restructured into the planned `App/ Features/ Core/ Models/ DesignSystem/`, `EmulatorConfig` and a stub `FirebaseSetup` are in place, the ATS exception is wired, and `StewardTests/` contains failing tests for the not-yet-added Firebase SDK + test target. The user has chosen **test-driven development** for this project.

The full implementation plan, phase breakdown, App Store compliance checklist, and CI/CD design lives at:

- `~/.claude/plans/pure-prancing-lecun.md` — the plan
- `~/.claude/projects/-Users-oriel-projects-steward-ios/memory/MEMORY.md` — auto-memory index (project overview, plan pointer, feedback memories)

**Read the plan before doing architectural work.** The CLAUDE.md only captures repo-level facts; the plan captures the cross-system context (web → iOS migration, Firebase backend reuse, Twilio Conversations REST/WebSocket strategy, Apple compliance gates).

## Editor: hybrid VS Code + Xcode

Day-to-day editing happens in **VS Code** (Claude Code attached) — Xcode stays open in the background for the things Apple's tooling does best. The `.vscode/` folder is committed and configures both halves:

- `.vscode/extensions.json` — recommends `swiftlang.swift-vscode` (SourceKit-LSP + LLDB). VS Code prompts to install on first open.
- `.vscode/settings.json` — hides `build/`, `.build/`, `DerivedData/`, `xcuserdata/` from explorer + search; pins file associations (`*.entitlements` → XML, `Package.resolved` → JSON).
- `.vscode/tasks.json` — wraps the `xcodebuild` / `xcrun simctl` / `swift test` commands into named tasks. Defaults: ⌘⇧B = Build app target, test runner = `swift test` for StewardCore. Other tasks: install + launch with/without auto-signin, light/dark screenshots, wipe app (sign out), start Firebase emulators, resolve SPM packages, print emulator host.
- `.vscode/launch.json` — LLDB attach config to debug the running simulator app + a launch config for StewardCore tests with the debugger.

**What stays in Xcode:**
- SwiftUI Previews — VS Code has no equivalent. Pop into Xcode for a quick render pass when iterating on UI.
- Capabilities (Sign In with Apple, Push, etc.), scheme env-var management, and signing/team settings — Xcode's UI is lower-friction. (We've also hand-edited `project.pbxproj` for these tonight; that path stays open.)
- Asset Catalog visual editor — plain text works for `.xcassets/*/Contents.json` but Xcode is faster.
- Storyboards / xibs — n/a here, the project is SwiftUI-only.

**Source-of-truth note:** the project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synced folders), so files saved in VS Code show up in Xcode automatically and vice versa. No manual "add to project" step.

## Building & running

Standard Xcode 26 app project — no workspace, no Pods, no `Package.swift`. Firebase SDK gets added later through Xcode's `File ▸ Add Package Dependencies…` UI.

```sh
# Build for simulator (current installed sim is iPhone 17 / iOS 26.4.1)
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests (requires the StewardTests target to be added first — see below)
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Clean
xcodebuild -project steward-ios.xcodeproj -scheme steward-ios clean
```

For day-to-day work, open `steward-ios.xcodeproj` in Xcode and use ⌘R / ⌘U.

## Local development against the steward web emulators

The iOS app is wired to talk to the Firebase emulator suite that ships with the sibling web project at `/Users/oriel/projects/steward/`. Running both side-by-side is the Phase 0 happy path — no real Firebase project needed until APNs/TestFlight come into play.

**1. Start the emulators** (in the web repo):

```sh
cd /Users/oriel/projects/steward
pnpm emulators
```

This runs `firebase emulators:start --only auth,firestore,functions,pubsub --import=./emulator-data --export-on-exit ./emulator-data`. Emulator UI: `http://localhost:4000`. Ports: Auth 9099, Firestore 8080, Functions 5001, Pub/Sub 8085. All bind to `0.0.0.0`, so the LAN reaches them too.

**2. Configure the iOS scheme.** `Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments ▸ Environment Variables`. Mark the scheme **Shared** so the env vars commit to git:

| Key             | Value (simulator)  | Value (tethered iPhone)            |
|-----------------|--------------------|------------------------------------|
| `USE_EMULATOR`  | `1`                | `1`                                |
| `EMULATOR_HOST` | `127.0.0.1`        | Mac's LAN IP (e.g. `192.168.x.y`)  |

For tethered device, run `./scripts/print-emulator-host.sh` from the repo root — it prints the right IP and the exact instructions.

**3. Sign in as the seeded bishop.** The web app's emulator data ships with `bishop@e2e.local` / `test1234` (uid `G2Bcy1N7aLAAkZd94WYqDwJ9cYwV`) in ward `stv1` ("Eglinton Ward"). Phase 0 uses email/password against the Auth emulator — Google Sign-In gets layered on later when the app starts pointing at the real `steward-dev-5e4dc` project. (The plan doc's "Google Sign-In with allowlist" line in Phase 0 is being amended.)

**4. The wiring lives in two files**, both gated so the project compiles even before the Firebase SPM packages are added:

- `steward-ios/App/EmulatorConfig.swift` — `isEnabled` / `host` derived from process env. Pure, unit-tested.
- `steward-ios/App/FirebaseSetup.swift` — `configure()` calls `FirebaseApp.configure()` and `useEmulator(...)` on Auth/Firestore/Functions when `EmulatorConfig.isEnabled`. `#if canImport(FirebaseCore)` guard means this is a no-op stub until the user adds Firebase via `File ▸ Add Package Dependencies…` (products: FirebaseAuth, FirebaseFirestore, FirebaseFunctions). Defer FirebaseMessaging until the APNs step.

**5. The Info.plist** is at the repo root (not under `steward-ios/`) deliberately — synced root groups would otherwise auto-include it as a copied resource and collide with the Info.plist processing step. `INFOPLIST_FILE = Info.plist` and `GENERATE_INFOPLIST_FILE = NO` in `project.pbxproj`. ATS allows local networking for emulator HTTP via `NSAllowsLocalNetworking = true`.

## Module layout: app target, StewardCore, StewardTests

The repo uses a **local Swift Package** at `LocalPackages/StewardCore` for testable, Firebase-free domain code. The reason is upstream: Firebase iOS SDK 12.x has an open SwiftPM transitive-linking bug on Xcode 26 ([firebase/firebase-ios-sdk#15642](https://github.com/firebase/firebase-ios-sdk/issues/15642), no fix as of 2026-04-28) — `FirebaseFirestore_PackageProduct.framework` fails to link abseil symbols when test-mode rebuilds the app target. To dodge it, we keep automated tests on a **standalone test bundle** that never depends on the app target or Firebase, and put everything testable into `StewardCore`.

| Component | Depends on | Notes |
|-----------|------------|-------|
| `LocalPackages/StewardCore` | nothing | Pure Swift. Public API for `EmulatorConfig` and (eventually) `FirestoreSubscription` protocols, view models, mocks. Add new testable code here, not in the app target. |
| `steward-ios` (app target) | `StewardCore`, `firebase-ios-sdk` (FirebaseAuth/Firestore/Functions), `abseil-cpp-binary`, `grpc-binary` | Builds and runs against the real Firestore emulator. The explicit `abseil` + `gRPC-C++` direct package references are required to make the app target link cleanly despite the upstream bug. |
| `StewardTests` | `StewardCore` only | **No** `TEST_HOST`, **no** target dependency on the app, **no** Firebase products. Standalone bundle, builds independently, sidesteps the Firebase SPM bug. |

**Practical workflow:**
- Live emulator demo → run the app from Xcode (⌘R) or `xcodebuild build` + simctl install. App target works fully.
- Automated tests → `xcodebuild test -scheme steward-ios` runs `StewardTests` against `StewardCore` only. Use mocks here, not the live emulators.
- New testable logic → add to `LocalPackages/StewardCore/Sources/StewardCore/` with `public` accessors, write tests in `StewardTests/`.
- `StewardTests/EmulatorConnectivityTests.swift` is gated `#if false && ...` as documented placeholder for the day Firebase fixes #15642 — flip the guard, restore TEST_HOST + the app target dependency in `project.pbxproj`, and re-add Firebase products to `StewardTests`.

## Test-driven development

**TDD is mandatory on this project.** Tests are written **before** the code they cover — no exceptions. Do not implement a feature, view model, subscription, or callable wrapper without a failing test in place first. If a change is too small or exploratory to warrant a test, it is also too small to commit; either grow it into something testable or throw it away.

**Always consult the `swift-testing-pro` skill before writing or reviewing tests.** Invoke it via the Skill tool at the start of any test-writing work — `@Suite` / `@Test` / `#expect` / `#require` / parameterized tests / `Trait`s / `confirmation` for async / `withKnownIssue` all have idiomatic forms the skill encodes, and we don't want to drift back to XCTest patterns. Run it again as a review pass after a non-trivial test file is written, and any time you're tempted to reach for `XCTAssert*`, `setUp`/`tearDown`, or `XCTestExpectation`.

Cadence (red → green → refactor):

1. **Write the test first** in `StewardTests/` using Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Run it and watch it fail for the right reason.
2. **Implement the minimum** to make it green.
3. **Refactor** once green, with the test as a safety net.

**Prioritize user-facing behavior over function-level coverage.** Write tests that describe what a bishopric user does and observes — "when the bishop opens the schedule, they see this Sunday's speakers in order", "when sign-in fails, the form shows an error and stays on screen" — not "this private helper returns 3". Drive view models and feature flows from the outside in: assert on the state a SwiftUI view would render (snapshot of a `@Published`/`@Observable` model, the `AttributedString` a row would display, the navigation destination a tap would push). Reach for finer-grained unit tests only when a behavior test can't pin down a tricky branch, or for pure value types like `EmulatorConfig` where there is no user-facing surface to anchor to. A green suite should give us confidence the *app works for the user*, not just that the functions return what they were written to return.

**Backfill tests for already-shipped features as you touch them.** Some Phase 0 code landed before this rule was tightened — that's fine, it's not too late. Whenever you read, modify, or extend an untested feature, add the user-facing behavior test it should have had in the first place *before* making your change. The test characterizes current behavior, then your edit either keeps it green or updates it deliberately. Don't open a separate "add tests" task and don't carve out a backfill epic; the coverage grows organically as we work. If a file you're editing has zero tests, that's the signal — write one now.

Currently in `StewardTests/`:
- `EmulatorConfigTests.swift` — pure unit tests against `StewardCore.EmulatorConfig`. Run on every `xcodebuild test`.
- `EmulatorConnectivityTests.swift` — integration tests, gated `#if false && canImport(FirebaseFirestore)` until the Firebase SPM upstream bug is fixed.
- `StewardTests.swift` — Xcode's boilerplate (can be deleted when convenient).

`xcodebuild test -scheme steward-ios -destination 'platform=iOS Simulator,name=iPhone 17'` runs the whole suite. The test bundle is standalone (no app dep), so adding new tests is fast — they don't drag the Firebase build along.

## Project structure rules

The Xcode project uses **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16+ synced folders). The `steward-ios/` directory on disk *is* the source group — adding, moving, or deleting Swift files in the filesystem auto-syncs into the build target. **Do not hand-edit `project.pbxproj` to add source files.** Just write the file to the right path on disk.

There's one important exception: **non-source files that the build system also needs to process specially (Info.plist, GoogleService-Info.plist) cannot live inside the synced group** without colliding with their dedicated processing steps. Keep them at the repo root and reference them via build settings (`INFOPLIST_FILE = Info.plist`).

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

## Auth model

The app routes through a four-state machine the moment `auth.isSignedIn`
flips, mirroring the web's `AuthGate` + `useWardAccess` pattern:

```
LoginView ──(sign in)──▶ checking ──▶ none      ──▶ AccessRequiredView
                                  ──▶ single    ──▶ ScheduleView(wardId)
                                  ──▶ multiple  ──▶ WardPickerView ──▶ ScheduleView
```

- **Two SSO providers + email/password.** `LoginView` shows "Continue with
  Google" and "Sign in with Apple" — both go through Firebase's unified
  `Auth.signIn(with: credential)`. The `signInWithGoogle()` path uses
  `OAuthProvider(providerID: "google.com").getCredentialWith(nil)`,
  which routes through `ASWebAuthenticationSession`. With
  `Auth.useEmulator(...)` set, that session opens the **Firebase Auth
  emulator's fake Google account chooser** at
  `localhost:9099/emulator/auth/handler` — same UX the web has, no real
  Google OAuth round-trip. No `GoogleSignIn-iOS` SDK; no SHA fingerprint
  dance. Apple Sign-In uses `SignInWithAppleButton` →
  `OAuthProvider.appleCredential(...)` → same `signIn(with:)` terminus.
  `bishop@e2e.local` / `test1234` debug shortcut stays for fast dev
  iteration in `#if DEBUG && EmulatorConfig.isEnabled`.
- **Allowlist gate.** `WardAccessClient` (in `StewardCore/Auth/`)
  subscribes to the `collectionGroup("members") where email == X and
  active == true` query — same query the web uses — and resolves
  `WardAccess.checking | none | single | multiple`. The Firestore
  adapter (`MemberAccessSource`) encodes `wardId/uid` from the doc path
  into the snapshot's `id` so the resolution stays a pure transform
  (testable without Firebase).
- **Current ward.** `CurrentWard` is the wardId every Firestore-scoped
  feature (schedule, soon week-editor, etc.) reads. Auto-resolved for
  single-ward members; the `WardPickerView` writes it for multi-ward
  members. Cleared on sign-out so listeners tear down cleanly.
- **Apple "Hide My Email" caveat.** Apple's private-relay
  `@privaterelay.appleid.com` addresses won't match a member doc's
  email and route the user to `AccessRequiredView`. The view detects
  the suffix and surfaces a hint: re-sign-in with "Share My Email".
  Long-term fix is to also key member docs on `auth.uid` — out of scope
  for this PR.
- **OAuth URL scheme.** `Info.plist` registers a `CFBundleURLTypes`
  entry with the project's `REVERSED_CLIENT_ID`
  (`com.googleusercontent.apps.159630054981-…`) so Google's OAuth
  callback can return to the app. Apple Sign-In needs the
  `com.apple.developer.applesignin` entitlement
  (`steward-ios.entitlements`); the IDE-side capability metadata isn't
  added to `project.pbxproj` (Xcode builds it without that — only the
  entitlement file matters). Free Apple ID provisioning may not
  support Apple Sign-In on physical devices; simulator works fine.

**Files of record:**
- `LocalPackages/StewardCore/Sources/StewardCore/Auth/{WardAccess,WardAccessClient,CurrentWard}.swift`
- `steward-ios/Core/Auth/{AuthClient,Nonce}.swift`
- `steward-ios/Core/Firestore/MemberAccessSource.swift`
- `steward-ios/Features/Auth/{LoginView,AccessRequiredView,WardPickerView}.swift`
- `steward-ios/App/RootView.swift` (the four-state state machine)

## Design system

iOS mirrors the web app's visual identity (cream parchment + walnut text +
bordeaux/brass accents, Newsreader serif + Inter sans + IBM Plex mono) via a
typed Swift API. **All UI work goes through these tokens** — do not reach for
ad-hoc `Color(red:...)`, magic spacing numbers, or `.font(.title)` overrides.

- **Token home:** `LocalPackages/StewardCore/Sources/StewardCore/DesignSystem/`
  (`Colors.swift`, `Fonts.swift`, `Spacing.swift`, `Radii.swift`,
  `Shadows.swift`).
- **Reusable views:** `StatusBadge`, `AppBarHeader`, `CardSurface` (the
  `.cardSurface()` modifier) — same module.
- **Font bundle:** `steward-ios/Resources/Fonts/*.ttf` (Newsreader, Inter
  Variable, IBM Plex Mono — all OFL, see bundled `LICENSES.md`). Registered
  via `UIAppFonts` in `Info.plist`. PostScript names are verified on launch
  by `steward-ios/App/FontAudit.swift` (DEBUG-only; prints to launch console).
- **Liquid Glass:** used sparingly, only where the web expresses the same
  idea (`backdrop-blur-sm`). Floating toolbar buttons + primary CTA — yes.
  Card surfaces and dense list rows — no, they need solid fills for
  legibility.
- **Dark mode:** supported alongside light. Tokens resolve dynamically via
  `UIColor(dynamicProvider:)`; consumers just write `Color.walnut` and the
  right hex appears.

**Full reference:** [`docs/design-resources.md`](docs/design-resources.md)
maps each web token → iOS API, lists the four-state status mapping, and
documents when to reach for Liquid Glass.

## Skills to use while writing code

The user has explicitly asked that we lean on the available `swiftui-*` and `swift-*` skills proactively rather than retrofitting. See the `feedback_use_swift_skills.md` auto-memory for the full cadence; the short version:

- Consult **swiftui-ui-patterns** and **swift-concurrency-pro** *as you write*.
- Run **swiftui-pro** after any non-trivial view; **swiftui-liquid-glass** for iOS 26 surfaces.
- Run **swift-security-expert** before merging anything that touches Keychain, OAuth tokens, FCM tokens, or Twilio JWTs.
- Run **swift-testing-pro** *before* writing any test (TDD is mandatory — see the Test-driven development section); **simplify** after larger chunks.

## Conventions specific to this codebase

- **Don't reimplement server-side crypto.** Capability tokens, invitation hashing, and SMS bridging all stay in `functions/` on the web repo. iOS only invokes callables (`issueSpeakerSession`, `sendSpeakerInvitation`) and never sees plaintext secrets.
- **Lexical content is read-only on iOS** for v1. Authoring stays on the web. Any `letterTemplates` / `programTemplates` rendering walks the serialized Lexical JSON tree into `AttributedString` — it does not edit it.
- **Speaker-side flows stay on the web.** This iOS app is bishopric-only; there is no public-link / unauthenticated surface to build.
