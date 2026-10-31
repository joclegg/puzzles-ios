import SwiftUI
import TwoToneEngine

enum TwoToneGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(TwoToneHomeView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = fixtureRef(name) else {
                return nil
            }
            return AnyView(TwoToneHomeView(fixture: ref))
        #else
            return nil
        #endif
    }

    #if DEBUG
        private static func fixtureRef(_ name: String) -> PuzzleRef? {
            guard let solution = Grid.parse(size: 4, text: "RBBR BRRB RBRB BRBR") else {
                return nil
            }
            let givens: TwoToneEngine.Grid
            switch name {
            case "two_tone_one_left":
                givens = solution.with(cell: 1, tile: .empty)
            case "two_tone_two_left":
                givens = solution.with(cell: 1, tile: .empty).with(cell: 2, tile: .empty)
            default:
                return nil
            }
            return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(givens: givens, solution: solution))
        }
    #endif
}
