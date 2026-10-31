import KakuroEngine
import SwiftUI

enum KakuroGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(KakuroRootView(fixture: nil))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = fixtureRef(name) else {
                return nil
            }
            return AnyView(KakuroRootView(fixture: ref))
        #else
            return nil
        #endif
    }

    #if DEBUG
        private static func fixtureRef(_ name: String) -> PuzzleRef? {
            let solution = [0, 0, 0, 0, 1, 2, 0, 3, 4]
            switch name {
            case "kakuro_one_left":
                return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(size: 3, solution: solution, givens: [4, 5, 7]))
            case "kakuro_empty":
                return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(size: 3, solution: solution))
            default:
                return nil
            }
        }
    #endif
}
