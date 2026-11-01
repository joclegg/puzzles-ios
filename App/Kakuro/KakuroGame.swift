import KakuroEngine
import PuzzlesCore
import SwiftUI

enum KakuroGame {
    @MainActor
    static let dailies = DailyProvider<Int>(
        tab: .kakuro, group: { _ in "KAKURO" }, options: sizes, label: sizeLabel, tag: { "daily_play_kakuro_\($0)" },
        results: {
            KakuroStore.shared.games.filter { $0.status == .solved }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let store = KakuroStore.shared
            return { size in
                let id = PuzzleRef.dailyId(date: date, size: size)
                return store.games.contains { $0.ref.id == id && $0.status == .solved }
            }
        },
        open: { date, size in await openDaily(size: size, date: date) }
    )

    @MainActor
    private static func openDaily(size: Int, date: CalendarDay) async -> String? {
        let store = KakuroStore.shared
        let id = PuzzleRef.dailyId(date: date, size: size)
        if let existing = store.inProgress.first(where: { $0.ref.id == id }) {
            return String(existing.id)
        }
        let puzzles = (try? await KakuroBank.puzzles(size: size)) ?? []
        guard !puzzles.isEmpty else {
            return nil
        }
        return String(store.start(ref: PuzzleRef.daily(puzzles: puzzles, date: date, size: size)).id)
    }

    @MainActor
    static func home() -> AnyView {
        AnyView(KakuroRootView(fixture: nil))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = fixtureRef(name) else {
                return nil
            }
            return AnyView(KakuroRootView(fixture: ref))
        #else
            return nil
        #endif
    }

    #if DEBUG
        private static func fixtureRef(_ name: String) -> PuzzleRef? {
            let solution = [0, 0, 0, 0, 1, 2, 0, 3, 4]
            switch name {
            case "kakuro_one_left":
                return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(size: 3, solution: solution, givens: [4, 5, 7]))
            case "kakuro_empty":
                return PuzzleRef(id: "fixture_\(name)", puzzle: Puzzle(size: 3, solution: solution))
            default:
                return nil
            }
        }
    #endif
}
