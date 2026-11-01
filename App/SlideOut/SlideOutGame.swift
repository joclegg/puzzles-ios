import PuzzlesCore
import SlideOutEngine
import SwiftData
import SwiftUI

enum SlideOutGame: GameDefinition {
    typealias Record = SlideOutGameRecord

    static let tab = SettingsTab.slideOut
    static let syncKey = "slideOut"

    static var context: ModelContext {
        SlideOutStore.context
    }

    @MainActor
    static let dailies = DailyProvider<Level>(
        tab: .slideOut, group: { _ in "SLIDE_OUT" }, options: Level.allCases, label: { $0.label },
        tag: { "daily_play_slide_out_\($0.name.lowercased())" },
        results: {
            SlideOutStore.solvedGames().compactMap { dailyResult(id: $0.puzzleId, finishedAt: $0.finishedAt) }
        },
        solved: { date in
            let left = Set(SlideOutStore.dailiesLeft(today: date))
            return { !left.contains($0) }
        },
        open: { date, level in await openDaily(level, date: date) }
    )

    @MainActor
    private static func openDaily(_ level: Level, date: CalendarDay) async -> String? {
        if let existing = SlideOutStore.inProgress(puzzleId: PuzzleRef.dailyId(date: date, level: level)) {
            return String(existing)
        }
        guard let ref = await attempt("Slide Out bank", { try await SlideOutBank.shared.daily(level, date: date) }) else {
            return nil
        }
        return String(SlideOutStore.start(ref))
    }

    @MainActor
    static func home() -> AnyView {
        AnyView(SlideOutHomeView().modelContainer(SlideOutStore.container))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = SlideOutFixtures.puzzle(name) else {
                return nil
            }
            return AnyView(SlideOutHomeView(fixture: ref).modelContainer(SlideOutStore.container))
        #else
            return nil
        #endif
    }
}
