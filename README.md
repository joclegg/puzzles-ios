# puzzles-ios

The iOS version of Puzzles, an offline puzzle collection: Sudoku (classic and killer), Klondike Solitaire, Two Tone, Sightlines, Five Letters, Kakuro, Slide Out and Word Wheel. It has the same games as [puzzles-android](https://github.com/joclegg/puzzles-android) and [puzzles-web](https://github.com/joclegg/puzzles-web), downloads the shared banks that [puzzles-data](https://github.com/joclegg/puzzles-data) publishes, and can sync with both through optional sign-in.

Built with SwiftUI, SwiftData and Swift 6 for iOS 26. Open `Puzzles.xcodeproj` in Xcode and run the `PuzzlesApp` scheme, or see `AGENTS.md` for the commands.

Every merge to `main` publishes a GitHub release with an unsigned simulator build.

The repository's settings and Actions secrets are managed by [joclegg-infra](https://github.com/joclegg/joclegg-infra).
