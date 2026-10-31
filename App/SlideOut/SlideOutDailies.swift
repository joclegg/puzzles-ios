import PuzzlesCore
import SlideOutEngine

enum SlideOutDailies {
    static var rules: CalendarRules {
        CalendarRules(total: Level.allCases.count)
    }

    @MainActor
    static var results: [DailyResult] {
        SlideOutStore.solvedGames().compactMap { dailyResult(id: $0.puzzleId, finishedAt: $0.finishedAt) }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let left = Set(SlideOutStore.dailiesLeft(today: date))
        return Level.allCases.map { level in
            let done = !left.contains(level)
            return GameDaily(
                tab: .slideOut, group: "SLIDE_OUT", label: level.label, tag: "daily_play_slide_out_\(level.name.lowercased())", done: done,
                offered: !done
            ) {
                if let existing = SlideOutStore.inProgress(puzzleId: PuzzleRef.dailyId(date: date, level: level)) {
                    return String(existing)
                }
                guard let ref = try? await SlideOutBank.shared.daily(level, date: date) else {
                    return nil
                }
                return String(SlideOutStore.start(ref))
            }
        }
    }
}
