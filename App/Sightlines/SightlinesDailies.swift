import PuzzlesCore
import SightlinesEngine

enum SightlinesDailies {
    static var rules: CalendarRules {
        CalendarRules(total: sizes.count)
    }

    @MainActor
    static var results: [DailyResult] {
        SightlinesStore.shared.games.filter { $0.status == .solved }.compactMap {
            dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = SightlinesStore.shared
        let solved = store.games.dailySolved(date: date)
        return sizes.map { size in
            let done = solved.contains(size)
            return GameDaily(
                tab: .sightlines, group: "SIGHTLINES", label: sizeLabel(size), tag: "daily_play_sightlines_\(size)", done: done,
                offered: !done
            ) {
                if let existing = store.games.dailyInProgress(date: date, size: size) {
                    return String(existing.id)
                }
                return String(await store.start { PuzzleRef.daily(date: date, size: size) })
            }
        }
    }
}
