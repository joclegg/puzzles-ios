import PuzzlesCore
import Testing

@testable import FiveLettersEngine

private let date = CalendarDay(year: 2026, month: 10, day: 31)
private let words = Words(answers: ["crane", "slate", "trace"], guesses: ["adieu"])

private func finished(_ status: GameStatus, guesses: Int, at time: Int64) -> SavedGame {
    SavedGame(
        uuid: "\(time)",
        ref: WordRef(id: "practice_\(time)", answer: "CRANE"),
        guesses: Array(repeating: "ADIEU", count: guesses),
        status: status,
        finishedAt: time
    )
}

struct WordRefTests {
    @Test(
        "given a word id when asked for its title then it names the game",
        arguments: [
            ("daily_2026-10-25", "Five Letters 1"),
            ("daily_2026-10-31", "Five Letters 7"),
            ("daily2_2026-10-31", "Daily puzzle 2 · 7"),
            ("nyt_2026-10-31", "Daily puzzle 2 · 7"),
            ("practice_5", "Practice"),
        ]
    )
    func title(id: String, expected: String) {
        // Act
        let title = WordRef(id: id, answer: "CRANE").title

        // Assert
        #expect(title == expected)
    }

    @Test(
        "given a word id when asked for its slot then dated games keep their own and practice shares one",
        arguments: [
            ("daily_2026-10-31", "daily_2026-10-31"),
            ("daily2_2026-10-31", "daily2_2026-10-31"),
            ("nyt_2026-10-31", "nyt_2026-10-31"),
            ("practice_5", "practice"),
            ("practice_6", "practice"),
        ]
    )
    func slot(id: String, expected: String) {
        // Act
        let slot = WordRef(id: id, answer: "CRANE").slot

        // Assert
        #expect(slot == expected)
    }

    @Test("given a date when refs are made then their ids carry it and the daily word comes from the list")
    func refsFromDate() {
        // Act
        let daily = WordRef.daily(words: words, date: date)
        let daily2 = WordRef.daily2(date: date, answer: "SLATE")

        // Assert
        #expect(daily.id == "daily_2026-10-31")
        #expect(daily.isDaily)
        #expect(daily.answer == words.daily(date))
        #expect(daily2.id == "daily2_2026-10-31")
        #expect(daily2.isDaily2)
        #expect(WordRef(id: "nyt_2026-10-31", answer: "SLATE").isDaily2)
    }

    @Test("given a seed when a practice ref is made then the same seed gives the same word")
    func practiceSeed() {
        // Act
        let first = WordRef.practice(words: words, seed: 9)
        let second = WordRef.practice(words: words, seed: 9)

        // Assert
        #expect(first == second)
        #expect(first.id == "practice_9")
    }
}

struct WordStatsTests {
    @Test("given no games when stats are worked out then everything is zero")
    func empty() {
        // Act
        let stats = WordStats(history: [])

        // Assert
        #expect(stats.played == 0)
        #expect(stats.winPercent == 0)
        #expect(stats.guessCounts == [0, 0, 0, 0, 0, 0])
    }

    @Test("given wins around a loss when stats are worked out then streaks follow finish order")
    func streaks() {
        // Arrange
        let history = [
            finished(.won, guesses: 3, at: 5),
            finished(.won, guesses: 3, at: 1),
            finished(.lost, guesses: 6, at: 3),
            finished(.won, guesses: 4, at: 2),
        ]

        // Act
        let stats = WordStats(history: history)

        // Assert
        #expect(stats.played == 4)
        #expect(stats.won == 3)
        #expect(stats.winPercent == 75)
        #expect(stats.currentStreak == 1)
        #expect(stats.maxStreak == 2)
        #expect(stats.guessCounts == [0, 0, 2, 1, 0, 0])
    }

    @Test(
        "given an unfinished game when stats are worked out then it does not count",
        arguments: [GameStatus.inProgress, .abandoned]
    )
    func unfinishedIgnored(status: GameStatus) {
        // Act
        let stats = WordStats(history: [finished(status, guesses: 2, at: 1)])

        // Assert
        #expect(stats.played == 0)
    }

    @Test("given guess counts when bars are sized then the most common fills and an empty one keeps a sliver")
    func bars() {
        // Act
        let stats = WordStats(history: [finished(.won, guesses: 2, at: 1)])

        // Assert
        #expect(stats.barFraction(guesses: 2) == 1)
        #expect(stats.barFraction(guesses: 1) == 0.08)
    }
}

struct SavesTests {
    @Test(
        "given a saved game when it is restored then only an early loss counts as revealed",
        arguments: [
            (GameStatus.lost, 2, true),
            (GameStatus.lost, 6, false),
            (GameStatus.inProgress, 2, false),
        ]
    )
    func restored(status: GameStatus, guesses: Int, revealed: Bool) {
        // Arrange
        let game = finished(status, guesses: guesses, at: 1)

        // Act
        let state = game.gameState

        // Assert
        #expect(state.revealed == revealed)
        #expect(state.isLost == (status == .lost))
    }

    @Test("given guesses when encoded and decoded then they round trip, and none stays empty")
    func guessCodec() {
        // Assert
        #expect(decodeGuesses(encodeGuesses(["ADIEU", "CRANE"])) == ["ADIEU", "CRANE"])
        #expect(encodeGuesses(["ADIEU", "CRANE"]) == "ADIEU,CRANE")
        #expect(decodeGuesses("").isEmpty)
    }

    @Test(
        "given a Daily puzzle 2 reply when it is read then only a five-letter solution comes back",
        arguments: [
            (#"{"date":"2026-10-31","word":"crane"}"#, "CRANE" as String?),
            (#"{"word" : "Crane"}"#, "CRANE"),
            (#"{"word":"cranes"}"#, nil),
            ("not json", nil),
        ]
    )
    func daily2(json: String, expected: String?) {
        // Act
        let word = daily2Word(json: json)

        // Assert
        #expect(word == expected)
    }

    @Test("given a game when it ends then the result title reports it")
    func resultTitle() {
        // Assert
        #expect(GameState(answer: "CRANE", guesses: ["ADIEU", "CRANE"]).resultTitle == "Got it in 2!")
        #expect(GameState(answer: "CRANE", revealed: true).resultTitle == "The word was CRANE")
    }

    @Test("given a found first letter when a hint is asked for then it names the next one")
    func hint() {
        // Assert
        #expect(GameState(answer: "CRANE", guesses: ["CHAIR"]).hintMessage == "Letter 2 is R.")
    }

    @Test("given an ISO date when parsed then it is that day, and rubbish is nothing")
    func parseDate() {
        // Assert
        #expect(CalendarDay(iso: "2026-10-31") == date)
        #expect(CalendarDay(iso: "soon") == nil)
    }
}
