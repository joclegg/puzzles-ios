import PuzzlesCore
import TwoToneEngine

enum TwoToneDailies {
    static var rules: CalendarRules {
        CalendarRules(total: sizes.count)
    }

    @MainActor
    static var results: [DailyResult] {
        TwoToneStore.shared.history.filter { $0.gameStatus == .solved }.compactMap {
            dailyResult(id: $0.puzzleId, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = TwoToneStore.shared
        let solved = store.dailySolved(date: date)
        return sizes.map { size in
            let done = solved.contains(size)
            return GameDaily(
                tab: .twoTone, group: "TWO_TONE", label: sizeLabel(size), tag: "daily_play_two_tone_\(size)", done: done, offered: !done
            ) {
                String(await store.openDaily(date: date, size: size))
            }
        }
    }
}
