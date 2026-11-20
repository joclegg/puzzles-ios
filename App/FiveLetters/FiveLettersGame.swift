import FiveLettersEngine
import PuzzlesCore
import SwiftData
import SwiftUI

enum FiveLettersGame: GameDefinition {
    typealias Record = FiveLettersGameRecord

    static let tab = SettingsTab.fiveLetters
    static let syncKey = "fiveLetters"

    static var context: ModelContext {
        FiveLettersStore.shared.context
    }

    enum Daily {
        case word
        case daily2

        var label: String {
            self == .word ? "Word" : "Daily puzzle 2"
        }

        var tag: String {
            self == .word ? "daily_play_word" : "daily_play_daily2"
        }

        var calendarLabel: String {
            self == .word ? "Puzzles daily" : "Daily puzzle 2"
        }

        func id(_ date: CalendarDay) -> String {
            switch self {
            case .word:
                WordRef.dailyId(date)
            case .daily2:
                WordRef.daily2Id(date)
            }
        }
    }

    @MainActor
    static let dailies = DailyProvider<Daily>(
        tab: .fiveLetters, group: { _ in "FIVE_LETTERS" }, options: [.word, .daily2], firstMedal: .silver,
        label: \.label, tag: \.tag, calendarLabel: \.calendarLabel,
        results: {
            FiveLettersStore.shared.history.filter { $0.status == .won }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in { daily in won(daily.id(date)) } },
        offered: { date, daily, _ in daily == .word && !finished(daily.id(date)) },
        open: { date, daily in await openDaily(daily, date: date) },
        shareBody: { date in
            let store = FiveLettersStore.shared
            let puzzles = store.existing(wordId: Daily.word.id(date)).flatMap(finishedShareText)
            let daily2 = store.existing(wordId: Daily.daily2.id(date))
                .flatMap { finishedDay($0.finishedAt) == date ? $0 : nil }
                .flatMap(finishedShareText)
            return fiveLettersDailiesBody(
                puzzles: puzzles ?? dailyShareLine(DailyShareEntry(label: Daily.word.calendarLabel, timeMs: nil)),
                daily2: daily2)
        }
    )

    @MainActor
    private static func finishedShareText(_ game: SavedGame) -> String? {
        guard game.status == .won || game.status == .lost else {
            return nil
        }
        return game.gameState.shareText(title: game.ref.title)
    }

    @MainActor
    private static func won(_ id: String) -> Bool {
        FiveLettersStore.shared.history.contains { $0.ref.id == id && $0.status == .won }
    }

    @MainActor
    private static func finished(_ id: String) -> Bool {
        FiveLettersStore.shared.history.contains { $0.ref.id == id && ($0.status == .won || $0.status == .lost) }
    }

    @MainActor
    private static func openDaily(_ daily: Daily, date: CalendarDay) async -> String? {
        let store = FiveLettersStore.shared
        if let existing = store.existing(wordId: daily.id(date)) {
            return existing.uuid
        }
        switch daily {
        case .word:
            guard let words = await attempt("Five Letters words", { try await store.words() }) else {
                return nil
            }
            return store.start(ref: .daily(words: words, date: date), hardMode: FiveLettersSetting.hardMode.current).uuid
        case .daily2:
            guard let answer = await FiveLettersDaily2.word(date: date.isoString) else {
                return nil
            }
            return store.start(ref: .daily2(date: date, answer: answer), hardMode: FiveLettersSetting.hardMode.current).uuid
        }
    }

    @MainActor
    static func home() -> AnyView {
        AnyView(FiveLettersHomeView())
    }

    static func reloadAfterSync() {
        FiveLettersStore.shared.refresh()
    }

    @MainActor
    static func fixtureBank(_ name: String) -> [String: [String]]? {
        #if DEBUG
            switch name {
            case "five_letters_crane":
                return ["words/answers.txt": ["crane"], "words/guesses.txt": ["trace"]]
            case "five_letters_daily":
                return ["words/answers.txt": ["crane"], "words/guesses.txt": ["adieu"]]
            case "five_letters_home":
                return [:]
            default:
                return nil
            }
        #else
            return nil
        #endif
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            switch name {
            case "five_letters_crane":
                return AnyView(FiveLettersHomeView(fixture: WordRef(id: "practice_fixture", answer: "CRANE")))
            default:
                return nil
            }
        #else
            return nil
        #endif
    }
}
