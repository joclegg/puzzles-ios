import PuzzlesCore
import SwiftUI
import TwoToneEngine

enum TwoToneGame {
    @MainActor
    static let dailies = DailyProvider<Int>(
        tab: .twoTone, group: { _ in "TWO_TONE" }, options: sizes, label: sizeLabel, tag: { "daily_play_two_tone_\($0)" },
        results: {
            TwoToneStore.shared.history.filter { $0.gameStatus == .solved }.compactMap {
                dailyResult(id: $0.puzzleId, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let solved = TwoToneStore.shared.dailySolved(date: date)
            return { solved.contains($0) }
        },
        open: { date, size in
            String(await TwoToneStore.shared.openDaily(date: date, size: size))
        }
    )

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
