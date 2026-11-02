import PuzzlesCore
import SightlinesEngine
import SwiftData
import SwiftUI

enum SightlinesGame: GameDefinition {
    typealias Record = SightlinesGameRecord

    static let tab = SettingsTab.sightlines
    static let syncKey = "sightlines"

    static var context: ModelContext {
        SightlinesStore.shared.context
    }

    @MainActor
    static let dailies = DailyProvider<Int>(
        tab: .sightlines, group: { _ in "SIGHTLINES" }, options: sizes, label: sizeLabel, tag: { "daily_play_sightlines_\($0)" },
        results: {
            SightlinesStore.shared.games.filter { $0.status == .solved }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let solved = SightlinesStore.shared.games.dailySolved(date: date)
            return { solved.contains($0) }
        },
        open: { date, size in await openDaily(size: size, date: date) }
    )

    @MainActor
    private static func openDaily(size: Int, date: CalendarDay) async -> String? {
        let store = SightlinesStore.shared
        if let existing = store.games.dailyInProgress(date: date, size: size) {
            return String(existing.id)
        }
        return String(await store.start { PuzzleRef.daily(date: date, size: size) })
    }

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
