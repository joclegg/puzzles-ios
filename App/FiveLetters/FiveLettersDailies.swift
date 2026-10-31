import FiveLettersEngine
import PuzzlesCore

enum FiveLettersDailies {
    static var rules: CalendarRules {
        CalendarRules(total: 2, firstMedal: .silver)
    }

    @MainActor
    static var results: [DailyResult] {
        FiveLettersStore.shared.history.filter { $0.status == .won }.compactMap {
            dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = FiveLettersStore.shared
        let daily = WordRef.dailyId(date)
        let nyt = WordRef.nytId(date)
        let finished = store.history.contains { $0.ref.id == daily && ($0.status == .won || $0.status == .lost) }
        return [
            GameDaily(
                tab: .fiveLetters, group: "FIVE_LETTERS", label: "Word", tag: "daily_play_word",
                done: store.history.contains { $0.ref.id == daily && $0.status == .won }, offered: !finished,
                calendarLabel: "Puzzles daily"
            ) {
                if let existing = store.existing(wordId: daily) {
                    return existing.uuid
                }
                guard let words = try? await store.words() else {
                    return nil
                }
                return store.start(ref: .daily(words: words, date: date), hardMode: FiveLettersSetting.hardMode.current).uuid
            },
            GameDaily(
                tab: .fiveLetters, group: "FIVE_LETTERS", label: "NY Times", tag: "daily_play_nyt",
                done: store.history.contains { $0.ref.id == nyt && $0.status == .won }, offered: false,
                calendarLabel: "NY Times daily"
            ) {
                if let existing = store.existing(wordId: nyt) {
                    return existing.uuid
                }
                guard let answer = await FiveLettersNyt.word(date: date.isoString) else {
                    return nil
                }
                return store.start(ref: .nyt(date: date, answer: answer), hardMode: FiveLettersSetting.hardMode.current).uuid
            },
        ]
    }
}
