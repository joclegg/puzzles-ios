import PuzzlesCore
import SudokuEngine
import SwiftUI

enum SudokuGame {
    @MainActor
    static let dailies = DailyProvider<(mode: GameMode, level: Difficulty)>(
        tab: .sudoku, group: { "SUDOKU_\($0.mode.rawValue)" },
        options: GameMode.allCases.flatMap { mode in mode.levels.map { (mode: mode, level: $0) } },
        label: { levelLabel($0.level) },
        tag: { "daily_play_\($0.mode.slug)_\($0.level.name.lowercased())" },
        calendarLabel: { "\($0.mode.label) \(levelLabel($0.level))" },
        results: {
            SudokuStore.shared.completedDailies.compactMap { game in
                DailyIds.parse(game.id).map { DailyResult(date: $0.date, id: game.id, finishedOn: finishedDay(game.finishedAt)) }
            }
        },
        solved: { date in
            let solved = Set(SudokuStore.shared.completedDailies.map(\.id))
            return { solved.contains(DailyIds.of(mode: $0.mode, difficulty: $0.level, date: date)) }
        },
        open: { date, option in
            (try? await SudokuStore.shared.openDaily(mode: option.mode, difficulty: option.level, date: date)).map(String.init)
        }
    )

    @MainActor
    static func home() -> AnyView {
        AnyView(SudokuRootView(fixture: nil))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard SudokuFixtures.names.contains(name) else {
                return nil
            }
            return AnyView(SudokuRootView(fixture: name))
        #else
            return nil
        #endif
    }
}
