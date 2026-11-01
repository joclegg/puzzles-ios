# AGENTS.md

## Structure

Puzzles for iOS: eight games (Sudoku, Solitaire, Two Tone, Sightlines, Five Letters, Kakuro, Slide Out, Word Wheel) that match puzzles-android and puzzles-web and play offline. SwiftUI, SwiftData, Swift 6 for iOS 26, no third-party packages.

- `Package.swift`: the Swift package with every engine, `PuzzlesCore` and `PuzzlesSync`, and their test targets.
- `Sources/<Game>Engine/`: every rule of one game as pure functions on its state, with no SwiftUI or SwiftData.
- `Sources/PuzzlesCore/`: code every engine shares: `XorWowRandom` (matches Kotlin's `Random(seed)` and puzzles-web's `createRandom`), `CalendarDay`, daily medals, `GameTimer`, `PuzzleStatus`, `DailyId`, `CellChangeCodec`, `formatDuration` and the size and date labels.
- `Sources/PuzzlesSync/`: PKCE and sign-in URLs, `SupabaseAuth` and `SyncEngine`.
- `Tests/<Target>Tests/`: Swift Testing suites, one folder per package target.
- `App/PuzzlesApplication.swift`, `App/RootView.swift`: the app entry point; `RootView` starts the bank download and `BankGate` holds back only a game whose banks are not on the device yet.
- `App/Shared/`: what every game uses: `GameDefinition` (the protocol each game implements, and `Games.all`), `BankStore`, `DailyProvider`, `ErrorLog` and `attempt`, `ModelContext` reporting helpers, `StatsTable`, `HomeSection`, `ThemeTokens` (`Color(hex:)`, `Color(light:dark:)`, history dates), `WinDialog`, `PuzzleIcon`, `GameMenu`, helpers and back swipe.
- `App/Launcher/`: the launcher, the settings hub, the all-games history, today's dailies and the daily calendar.
- `App/Sync/`: `SyncCenter`, sign-in, `GameSyncSource` and the settings bridges.
- `App/<Game>/`: one game, with the same files in every game:
  - `<Game>Game.swift`: its `GameDefinition` (tab, sync key, store context, dailies, home and debug fixtures)
  - `<Game>Store.swift`: its SwiftData `@Model` record and `@Observable` store; Sudoku keeps its records in `SudokuRecords.swift`
  - `<Game>GameModel.swift`: the `@Observable` model behind one game in play
  - `<Game>GameView.swift`, `<Game>BoardView.swift`, `<Game>HomeView.swift`, `<Game>StatsView.swift` (stats and history), `<Game>SettingsView.swift`, `<Game>Theme.swift`
  - Extra files only for what one game alone has, such as `SudokuEntryView.swift` or `WordWheelHelp.swift`
- `e2e/flows/`: Maestro flows, one behaviour per file, named `<game>_<behaviour>.yaml`. `e2e/run.sh` builds, installs and runs them on one simulator (`--fast`, `--part I/N`, a flow path, `E2E_DEVICE`, `E2E_APP_PATH`). `e2e/partition.sh` splits flows by the seconds in `e2e/flow-times.txt`; `e2e/fetch-banks.sh` puts the banks in `/tmp/puzzles-e2e-banks` for debug simulator builds.
- `scripts/verify-no-comments.sh`: the no-comments check.
- `Puzzles.xcodeproj`: the app target, using a synchronised `App` folder, so new files in `App/` need no project change.
- `Puzzles-Info.plist`: only the `com.joclegg.puzzles://` URL scheme; the rest is generated.

## Conventions

- MUST keep these passing: `xcrun swift-format lint --strict --recursive App Sources Tests Package.swift`, `scripts/verify-no-comments.sh`, `swift test -c release -Xswiftc -enable-testing -j 4`, `xcodebuild -project Puzzles.xcodeproj -scheme PuzzlesApp -destination 'generic/platform=iOS Simulator' -derivedDataPath build -jobs 4 build` and `e2e/run.sh`.
- MUST format with `xcrun swift-format format -i --recursive App Sources Tests Package.swift`.
- MUST NOT write comments, except Arrange, Act and Assert markers in tests.
- MUST write commits in Conventional Commits style. MUST NOT create `v*` tags by hand: every merge to `main` publishes a release.
- MUST NOT commit secrets. The Supabase publishable key is public, as it is on Android; settings and Actions secrets are managed in joclegg-infra.
- MUST NOT run more than one simulator or build at a time on a laptop, and MUST pass `-jobs 4` to `xcodebuild`.
- MUST NOT trust a local build alone: GitHub's `macos-26` runner can be on an older Xcode than yours.
- MUST have the same eight games as puzzles-android and puzzles-web, behaving the same; a change to one usually needs the same change in the others.
- MUST read Android from `origin/main` of puzzles-android, not a local checkout that may be behind.
- MUST put every game rule in that game's engine under `Sources/` as a pure function with tests. MUST NOT depend on one game's engine from another; shared rules go in `PuzzlesCore`.
- MUST draw every random number from `XorWowRandom`, in the same order as Android, so seeded and daily puzzles match on every platform.
- MUST keep daily ids, SwiftData models and sync JSON identical to Android and web. MUST NOT rename a SwiftData `@Model` class or stored property, or change what it persists.
- MUST define exactly one `GameDefinition` per game in `<Game>Game.swift` and list it in `Games.all`, and MUST give every game the same file names and roles.
- MUST put UI that several games share in `App/Shared` and use it instead of a per-game copy, matching Android's `core/ui`.
- MUST take tool and menu icons from `PuzzleIcon`, generated from Android's vector paths.
- MUST download puzzle banks from https://joclegg.github.io/puzzles-data/ through `BankStore` and keep them on the device. MUST NOT bundle puzzle banks in the app or the repository.
- MUST NOT add analytics, crash reporting or ads. The only network calls are bank downloads, sync and the Five Letters Daily puzzle 2 word from https://puzzles-daily.joclegg.dev.
- MUST keep sign-in optional, so every game plays signed out.
- MUST give every element a flow touches an `accessibilityIdentifier` using Android's test tag, and MUST NOT change an identifier a flow uses.
- MUST keep fixtures debug-only, through the `fixture` launch argument.
- MUST run flows on a simulator kept for them; with Xcode 27.2 that means `DeviceHub.app` in `/Applications/Xcode.app/Contents/Applications/`, and Maestro needs Java 21.
- MUST add new or much slower flows to `e2e/flow-times.txt` from a CI run's `[Passed]` lines.
- MUST follow the Swift API Design Guidelines: clear names at the point of use, `UpperCamelCase` types, `lowerCamelCase` everything else, no abbreviations.
- MUST compile with Swift 6 strict concurrency. MUST NOT use `@unchecked Sendable` or `nonisolated(unsafe)` in app code.
- MUST NOT force unwrap, force cast or use `try!` outside tests.
- MUST NOT swallow persistence, network or bank errors with `try?`; report them with `attempt`, `fetchOrEmpty`, `saveOrReport` or `ErrorLog.report`. `try?` is only for parsing where `nil` is the answer.
- MUST keep business logic out of views: views read `@Observable` models and stores and call their methods.
- MUST use `@Observable` for models and stores. MUST NOT use `ObservableObject`.
