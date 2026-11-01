# puzzles-ios

Puzzles is a collection of eight logic and word games for iPhone that play fully offline once their puzzles are downloaded. This is the iOS app; [puzzles-android](https://github.com/joclegg/puzzles-android) and [puzzles-web](https://github.com/joclegg/puzzles-web) have the same games, and an optional sign-in syncs scores and history across all three.

## The games

- **Sudoku**: classic and killer, from 6x6 to evil
- **Solitaire**: Klondike, draw one or three, or reverse
- **Two Tone**: fill the grid red and blue by three simple rules
- **Sightlines**: blue dots count the dots they can see
- **Five Letters**: guess the word in six tries, with a new one every day
- **Kakuro**: cross sums, runs of different digits that add up
- **Slide Out**: slide the blocks to free the red one
- **Word Wheel**: swipe the letters to fill a crossword

Every game has daily puzzles, stats and a history, and a shared calendar tracks the dailies.

## How it's built

- SwiftUI for the interface, SwiftData for saved games and `@AppStorage` for settings, with Swift 6 strict concurrency
- The rules of each game live in a Swift package target (`Sources/<Game>Engine`) as pure, tested functions, with shared code in `PuzzlesCore` and sync in `PuzzlesSync`
- The app target (`App/`) holds the screens, one folder per game, built on shared components in `App/Shared`
- Puzzle banks come from [puzzles-data](https://github.com/joclegg/puzzles-data) at runtime and stay on the device; sync uses the shared [puzzles-backend](https://github.com/joclegg/puzzles-backend)
- No third-party packages

## Build, run and test

- Open `Puzzles.xcodeproj` in Xcode and run the `PuzzlesApp` scheme on a simulator
- `swift test -c release -Xswiftc -enable-testing`: the unit tests for every engine
- `e2e/run.sh`: build the app and run the Maestro flows on a simulator

`AGENTS.md` lists every command and the repository's rules. Every merge to `main` publishes a GitHub release with an unsigned simulator build. The repository's settings and Actions secrets are managed by [joclegg-infra](https://github.com/joclegg/joclegg-infra).
