import PuzzlesCore
import Testing

@testable import WordWheelEngine

private func puzzle(_ word: String) -> Puzzle {
    Puzzle(letters: word, crossword: Crossword(placements: [Placement(word: word, row: 0, col: 0, across: true)]))
}

private let bank = (0..<50).map { puzzle("W\($0)") }

struct SavedGameTests {
    @Test("given a date when the daily is picked twice then it is the same puzzle and id")
    func dailyIsStable() {
        // Arrange
        let date = CalendarDay(year: 2026, month: 10, day: 31)

        // Act
        let first = PuzzleRef.daily(puzzles: bank, date: date, level: .six)
        let second = PuzzleRef.daily(puzzles: bank, date: date, level: .six)

        // Assert
        #expect(first == second)
        #expect(first.id == "daily_2026-10-31_six")
    }

    @Test("given consecutive dates when dailies are picked then a full cycle never repeats")
    func dailiesCycle() {
        // Arrange
        let start = CalendarDay(year: 2026, month: 10, day: 25)

        // Act
        let picked = (0..<bank.count).map {
            PuzzleRef.daily(puzzles: bank, date: start.adding(days: $0), level: .five).puzzle
        }

        // Assert
        #expect(Set(picked).count == bank.count)
    }

    @Test("given a date before the first day when the daily is picked then it wraps to a puzzle")
    func dailyBeforeFirstDay() {
        // Act
        let ref = PuzzleRef.daily(puzzles: bank, date: CalendarDay(year: 2026, month: 1, day: 1), level: .seven)

        // Assert
        #expect(bank.contains(ref.puzzle))
    }

    @Test("given a seed when a random puzzle is picked then its id names the level and index")
    func randomId() {
        // Act
        let ref = PuzzleRef.random(puzzles: bank, level: .seven, seed: 42)

        // Assert
        #expect(ref.id.hasPrefix("bank_SEVEN_"))
        #expect(bank.contains(ref.puzzle))
    }

    @Test("given a ref when its slot and title are read then dailies stand alone and the rest share a level")
    func slotAndTitle() {
        // Arrange
        let daily = PuzzleRef.daily(puzzles: bank, date: CalendarDay(year: 2026, month: 10, day: 31), level: .five)
        let random = PuzzleRef.random(puzzles: bank, level: .five, seed: 1)

        // Assert
        #expect(daily.isDaily)
        #expect(daily.slot == daily.id)
        #expect(daily.title == "Daily · 31 Oct · 5 letters")
        #expect(!random.isDaily)
        #expect(random.slot == "FIVE")
        #expect(random.title == "5 letters")
    }

    @Test("given finished and running games when stats are made then only finished ones count")
    func stats() {
        // Arrange
        let ref = PuzzleRef(id: "x", level: .five, puzzle: puzzle("CAT"))
        let games = [
            SavedGame(id: 1, ref: ref, bonus: ["A", "B"], elapsedMs: 9000, status: .solved, startedAt: 0),
            SavedGame(id: 2, ref: ref, elapsedMs: 5000, status: .solved, startedAt: 0),
            SavedGame(id: 3, ref: ref, bonus: ["C"], elapsedMs: 1000, status: .revealed, startedAt: 0),
            SavedGame(id: 4, ref: ref, bonus: ["D"], elapsedMs: 1, status: .inProgress, startedAt: 0),
        ]

        // Act
        let stats = LevelStats.of(games, level: .five)

        // Assert
        #expect(stats.played == 3)
        #expect(stats.solved == 2)
        #expect(stats.bonusWords == 3)
        #expect(stats.bestMs == 5000)
    }

    @Test("given cells and words when encoded then they decode to the same values")
    func codec() throws {
        // Arrange
        let cells = [Cell(row: 1, col: 2), Cell(row: 3, col: 0)]

        // Act
        let encoded = SavedGameCodec.encodeCells(cells)

        // Assert
        #expect(encoded == "1:2,3:0")
        #expect(try SavedGameCodec.decodeCells(encoded) == cells)
        #expect(try SavedGameCodec.decodeCells("").isEmpty)
        #expect(SavedGameCodec.decodeWords(SavedGameCodec.encodeWords(["CAT", "DOG"])) == ["CAT", "DOG"])
        #expect(SavedGameCodec.decodeWords("").isEmpty)
    }

    @Test(
        "given a duration when formatted then it shows hours only when needed",
        arguments: [(Int64(0), "0:00"), (65_000, "1:05"), (3_725_000, "1:02:05")]
    )
    func duration(ms: Int64, expected: String) {
        // Assert
        #expect(formatDuration(ms) == expected)
    }

    @Test(
        "given a guess result when its message is read then it matches the game's wording",
        arguments: [
            (Guess.found, "Nice!"), (.bonus, "Bonus word!"), (.already, "Already found"), (.notAWord, "Not a word"),
            (.tooShort, "Three letters or more"),
        ]
    )
    func message(guess: Guess, expected: String) {
        // Assert
        #expect(guess.message == expected)
    }
}
