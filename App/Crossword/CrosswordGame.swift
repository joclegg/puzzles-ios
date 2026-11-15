import CrosswordEngine
import PuzzlesCore
import SwiftData
import SwiftUI

enum CrosswordGame: GameDefinition {
    typealias Record = CrosswordGameEntity

    static let tab = SettingsTab.crossword
    static let syncKey = "crossword"

    static var context: ModelContext {
        CrosswordStore.shared.context
    }

    @MainActor
    static let dailies = DailyProvider<Int>(
        tab: .crossword, group: { _ in "CROSSWORD" }, options: sizes, label: sizeName, tag: { "daily_play_crossword_\($0)" },
        results: {
            CrosswordStore.shared.games.filter { $0.status == .solved }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let store = CrosswordStore.shared
            return { size in
                let id = PuzzleRef.dailyId(date: date, size: size)
                return store.games.contains { $0.ref.id == id && $0.status == .solved }
            }
        },
        open: { date, size in await openDaily(size: size, date: date) }
    )

    @MainActor
    private static func openDaily(size: Int, date: CalendarDay) async -> String? {
        let store = CrosswordStore.shared
        let id = PuzzleRef.dailyId(date: date, size: size)
        if let existing = store.inProgress.first(where: { $0.ref.id == id }) {
            return String(existing.id)
        }
        let puzzles = await attempt("Crossword bank") { try await CrosswordBank.puzzles(size: size) } ?? []
        guard !puzzles.isEmpty else {
            return nil
        }
        return String(store.start(ref: PuzzleRef.daily(puzzles: puzzles, date: date, size: size)).id)
    }

    @MainActor
    static func home() -> AnyView {
        AnyView(CrosswordRootView(fixture: nil))
    }

    static func reloadAfterSync() {
        CrosswordStore.shared.reload()
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = fixtureRef(name) else {
                return nil
            }
            return AnyView(CrosswordRootView(fixture: ref))
        #else
            return nil
        #endif
    }

    #if DEBUG
        private static func fixtureRef(_ name: String) -> CrosswordFixture? {
            guard let puzzle = Puzzle.decode("3;CATA#OBOW") else {
                return nil
            }
            let ref = PuzzleRef(id: "fixture_\(name)", puzzle: puzzle)
            switch name {
            case "crossword_one_left":
                return CrosswordFixture(ref: ref, entries: Array("CATA#OBO."))
            case "crossword_empty":
                return CrosswordFixture(ref: ref, entries: nil)
            default:
                return nil
            }
        }
    #endif
}

struct CrosswordFixture {
    let ref: PuzzleRef
    let entries: [Character]?
}
