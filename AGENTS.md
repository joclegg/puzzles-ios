# AGENTS.md

Puzzles for iOS: eight games, playable offline after a first download of their puzzles. A launcher picks the game.

## Stack

- Swift 6, SwiftUI, iOS 26, SwiftData for saved games, `@AppStorage` for settings
- Swift Package targets for the rules (`Sources/<Game>Engine`), shared code (`PuzzlesCore`) and sync logic (`PuzzlesSync`), with an app target in `Puzzles.xcodeproj` that uses synchronised folders, so new files in `App/` need no project change
- Swift Testing for unit tests, Maestro for e2e flows, `swift-format` for formatting
- No third-party packages

## Commands

- `swift test -c release -Xswiftc -enable-testing -j 4`: run every unit test. Debug builds make the Sudoku tests take minutes
- `xcrun swift-format format -i --recursive App Sources Tests Package.swift`: format
- `xcrun swift-format lint --strict --recursive App Sources Tests Package.swift`: check formatting
- `scripts/verify-no-comments.sh`: check for comments
- `xcodebuild -project Puzzles.xcodeproj -scheme PuzzlesApp -destination 'generic/platform=iOS Simulator' -derivedDataPath build -jobs 4 build`: build
- `e2e/run.sh`: build, install and run every flow on one simulator
- `e2e/run.sh --fast`, `e2e/run.sh --part I/N`, `e2e/run.sh e2e/flows/<flow>.yaml`: run some of them
- `E2E_DEVICE=<simulator name> e2e/run.sh`: run on another simulator than `iPhone 17`. Use one kept for flows, not one someone is using by hand

## Structure

- `Sources/<Game>Engine/`: every rule of one game, as pure functions on its state. No SwiftUI
- `Sources/PuzzlesCore/`: `XorWowRandom`, which reproduces Kotlin's `Random(seed)` and puzzles-web's `createRandom`; `CalendarDay`; daily medals
- `Sources/PuzzlesSync/`: PKCE and sign-in URLs, `SupabaseAuth`, `SyncEngine`
- `App/<Game>/`: one game's screens, store and fixtures. `<Game>Game.swift` is its entry point
- `App/LauncherView.swift`, `SettingsHubView.swift`, `WinDialog.swift`, `DailyCalendar.swift`, `TodaysDailies.swift`, `PuzzleIcon.swift`, `BankStore.swift`, `BackSwipe.swift`: shared by every game
- `App/RootView.swift`: holds the launcher back until the banks are on the device
- `App/Sync/`: `SyncCenter`, sign-in, the per-game sync sources and settings mapping
- `e2e/flows/`: Maestro flows, one behaviour per file, named `<game>_<behaviour>.yaml`
- `Puzzles-Info.plist`: only the `com.joclegg.puzzles://` URL scheme; the rest is generated

## Working here

- `e2e/run.sh` runs `e2e/fetch-banks.sh`, which puts the banks in `/tmp/puzzles-e2e-banks`. Debug simulator builds copy them in on first launch, because the CI simulator's TLS fails, so e2e runs never exercise the first download.
- Maestro needs Java 21. `e2e/run.sh` uses Homebrew's `openjdk@21` when it's installed.
- Xcode 27.2 has no `Simulator.app`. Use `DeviceHub.app` in `/Applications/Xcode.app/Contents/Applications/`.
- GitHub's `macos-26` runner can be on an older Xcode than yours, so CI can fail on code that compiles locally.
- Read Android from `origin/main` of puzzles-android, not a local checkout that may be behind.
- Several games still keep their own copies of shared UI, such as headers, icon buttons and back buttons. Prefer one shared component, matching Android's `core/ui`, when you touch them.

## Rules

- MUST have the same eight games as puzzles-android and puzzles-web, and behave the same. A change to one usually needs the same change in the others.
- MUST keep `swift-format` lint, the no-comments check, unit tests, the build and the e2e flows passing.
- MUST NOT write comments, except Arrange, Act and Assert markers in tests.
- MUST write commits in Conventional Commits style. Every merge to `main` publishes a release; MUST NOT create `v*` tags by hand.
- MUST put each game rule in that game's engine as a pure function. MUST NOT depend on one game's engine from another.
- MUST draw every random number from `XorWowRandom`, in the same order as Android, so seeded and daily puzzles match on every platform.
- MUST keep daily ids and sync JSON identical to Android and web, because one account syncs across all three.
- MUST download puzzle banks from https://joclegg.github.io/puzzles-data/ through `BankStore`, and keep them on the device so every game plays offline. MUST NOT bundle puzzle banks in the app or the repository.
- MUST NOT add analytics, crash reporting or ads. The only network calls are bank downloads, sync and the Five Letters NY Times daily.
- MUST keep sign-in optional, so every game plays signed out.
- MUST NOT commit secrets. The Supabase publishable key is public, as it is on Android. This repository's settings and Actions secrets are managed in joclegg-infra.
- MUST take tool and menu icons from `PuzzleIcon`, generated from Android's vector paths.
- MUST give every element a flow touches an `accessibilityIdentifier`, using Android's test tag. Fixtures are debug-only, through the `fixture` launch argument.
- MUST NOT run more than one simulator or build at a time on a laptop. Pass `-jobs 4` to `xcodebuild`.
