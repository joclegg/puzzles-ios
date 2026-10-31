import SightlinesEngine
import SwiftUI

enum SightlinesGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(SightlinesHomeView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = fixtureRef(name) else {
                return nil
            }
            return AnyView(SightlinesHomeView(fixture: ref))
        #else
            return nil
        #endif
    }

    #if DEBUG
        private static func fixtureRef(_ name: String) -> PuzzleRef? {
            let open: Set<Int>
            switch name {
            case "sightlines_one_left":
                open = [1]
            case "sightlines_two_left":
                open = [1, 2]
            default:
                return nil
            }
            guard let solution = Grid.parse(size: 4, text: "BBRB BRBB RBBR BBRR") else {
                return nil
            }
            let cells = solution.dots.indices.filter { !open.contains($0) }
            var numbers: [Int: Int] = [:]
            var walls = Set<Int>()
            for cell in cells {
                if solution.dots[cell] == .blue {
                    numbers[cell] = solution.seen(cell)
                } else {
                    walls.insert(cell)
                }
            }
            return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(solution: solution, numbers: numbers, walls: walls))
        }
    #endif
}
