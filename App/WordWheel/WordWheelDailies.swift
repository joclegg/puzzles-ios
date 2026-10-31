import PuzzlesCore
import WordWheelEngine

enum WordWheelDailies {
    static var rules: CalendarRules {
        CalendarRules(total: Level.allCases.count)
    }

    @MainActor
    static var results: [DailyResult] {
        WordWheelRepository.shared.history.filter { $0.status == .solved }.compactMap {
            dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let repository = WordWheelRepository.shared
        let solved = repository.dailySolved(on: date)
        return Level.allCases.map { level in
            let done = solved.contains(level)
            return GameDaily(
                tab: .wordWheel, group: "WORD_WHEEL", label: level.label, tag: "daily_play_word_wheel_\(level.name.lowercased())",
                done: done,
                offered: !done
            ) {
                (try? await repository.openDaily(level, date: date)).map(String.init)
            }
        }
    }
}
