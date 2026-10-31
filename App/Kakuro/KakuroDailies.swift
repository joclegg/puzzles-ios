import KakuroEngine
import PuzzlesCore

enum KakuroDailies {
    static var rules: CalendarRules {
        CalendarRules(total: sizes.count)
    }

    @MainActor
    static var results: [DailyResult] {
        KakuroStore.shared.games.filter { $0.status == .solved }.compactMap {
            dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = KakuroStore.shared
        return sizes.map { size in
            let id = PuzzleRef.dailyId(date: date, size: size)
            let done = store.games.contains { $0.ref.id == id && $0.status == .solved }
            return GameDaily(
                tab: .kakuro, group: "KAKURO", label: sizeLabel(size), tag: "daily_play_kakuro_\(size)", done: done, offered: !done
            ) {
                if let existing = store.inProgress.first(where: { $0.ref.id == id }) {
                    return String(existing.id)
                }
                let puzzles = await KakuroBank.puzzles(size: size)
                guard !puzzles.isEmpty else {
                    return nil
                }
                return String(store.start(ref: PuzzleRef.daily(puzzles: puzzles, date: date, size: size)).id)
            }
        }
    }
}
