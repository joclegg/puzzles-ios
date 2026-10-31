import SwiftUI

struct LauncherView: View {
    private struct Game: Identifiable {
        let id: String
        let name: String
        let isPlayable: Bool
    }

    private let games = [
        Game(id: "sudoku", name: "Sudoku", isPlayable: false),
        Game(id: "solitaire", name: "Solitaire", isPlayable: false),
        Game(id: "two_tone", name: "Two Tone", isPlayable: false),
        Game(id: "sightlines", name: "Sightlines", isPlayable: false),
        Game(id: "five_letters", name: "Five Letters", isPlayable: true),
        Game(id: "kakuro", name: "Kakuro", isPlayable: false),
        Game(id: "slide_out", name: "Slide Out", isPlayable: false),
        Game(id: "word_wheel", name: "Word Wheel", isPlayable: false),
    ]

    var body: some View {
        NavigationStack {
            List(games) { game in
                if game.isPlayable {
                    NavigationLink(game.name) {
                        FiveLettersView()
                    }
                    .accessibilityIdentifier("game_\(game.id)")
                } else {
                    LabeledContent(game.name, value: "Coming soon")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("game_\(game.id)")
                }
            }
            .navigationTitle("Puzzles")
        }
    }
}
