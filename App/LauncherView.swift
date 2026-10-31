import SwiftUI

struct LauncherView: View {
    private struct Entry: Identifiable {
        let id: String
        let name: String
        let home: @MainActor () -> AnyView
        let fixture: @MainActor (String) -> AnyView?
    }

    private let entries = [
        Entry(id: "sudoku", name: "Sudoku", home: SudokuGame.home, fixture: SudokuGame.fixture),
        Entry(id: "solitaire", name: "Solitaire", home: SolitaireGame.home, fixture: SolitaireGame.fixture),
        Entry(id: "two_tone", name: "Two Tone", home: TwoToneGame.home, fixture: TwoToneGame.fixture),
        Entry(id: "sightlines", name: "Sightlines", home: SightlinesGame.home, fixture: SightlinesGame.fixture),
        Entry(id: "five_letters", name: "Five Letters", home: FiveLettersGame.home, fixture: FiveLettersGame.fixture),
        Entry(id: "kakuro", name: "Kakuro", home: KakuroGame.home, fixture: KakuroGame.fixture),
        Entry(id: "slide_out", name: "Slide Out", home: SlideOutGame.home, fixture: SlideOutGame.fixture),
        Entry(id: "word_wheel", name: "Word Wheel", home: WordWheelGame.home, fixture: WordWheelGame.fixture),
    ]

    var body: some View {
        NavigationStack {
            if let view = fixtureView {
                view
            } else {
                List(entries) { entry in
                    NavigationLink(entry.name) {
                        entry.home()
                    }
                    .accessibilityIdentifier("game_\(entry.id)")
                }
                .navigationTitle("Puzzles")
            }
        }
    }

    private var fixtureView: AnyView? {
        #if DEBUG
            guard let name = UserDefaults.standard.string(forKey: "fixture") else {
                return nil
            }
            return entries.lazy.compactMap { $0.fixture(name) }.first
        #else
            return nil
        #endif
    }
}
