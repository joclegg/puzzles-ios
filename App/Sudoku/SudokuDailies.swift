import PuzzlesCore
import SudokuEngine

enum SudokuDailies {
    static var rules: CalendarRules {
        CalendarRules(total: GameMode.allCases.reduce(0) { $0 + $1.levels.count })
    }

    @MainActor
    static var results: [DailyResult] {
        SudokuStore.shared.completedDailies.compactMap { game in
            DailyIds.parse(game.id).map { DailyResult(date: $0.date, id: game.id, finishedOn: finishedDay(game.finishedAt)) }
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = SudokuStore.shared
        let solved = Set(store.completedDailies.map(\.id))
        return GameMode.allCases.flatMap { mode in
            mode.levels.map { level in
                let done = solved.contains(DailyIds.of(mode: mode, difficulty: level, date: date))
                return GameDaily(
                    tab: .sudoku,
                    group: "SUDOKU_\(mode.rawValue)",
                    label: levelLabel(level),
                    tag: "daily_play_\(mode.slug)_\(level.name.lowercased())",
                    done: done,
                    offered: !done,
                    calendarLabel: "\(mode.label) \(levelLabel(level))"
                ) {
                    (try? await store.openDaily(mode: mode, difficulty: level, date: date)).map(String.init)
                }
            }
        }
    }
}
