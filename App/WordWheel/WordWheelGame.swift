import SwiftUI
import WordWheelEngine

enum WordWheelGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(WordWheelHomeView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = WordWheelFixtures.puzzle(name) else {
                return nil
            }
            return AnyView(WordWheelHomeView(fixture: ref))
        #else
            return nil
        #endif
    }
}

#if DEBUG
    enum WordWheelFixtures {
        static func puzzle(_ name: String) -> PuzzleRef? {
            switch name {
            case "word_wheel_two_words":
                guard let crossword = try? Crossword.decode("CRATE@0,0,A|TRACE@0,1,D") else {
                    return nil
                }
                return PuzzleRef(
                    id: "fixture_\(name)",
                    level: .five,
                    puzzle: Puzzle(letters: "TRACE", crossword: crossword)
                )
            default:
                return nil
            }
        }
    }
#endif
