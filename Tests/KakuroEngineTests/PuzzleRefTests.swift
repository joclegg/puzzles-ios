import PuzzlesCore
import Testing

@testable import KakuroEngine

struct PuzzleRefTests {
    private let bank = (1...9).map { puzzle(3, "000 0\($0)2 034") }
    private let day = CalendarDay(year: 2026, month: 10, day: 25)

    private func game(size: Int = 3, status: GameStatus, elapsedMs: Int64 = 0) -> SavedGame {
        let solution = [Int](repeating: 0, count: size * size)
        let ref = PuzzleRef(id: "x", puzzle: Puzzle(size: size, solution: solution))
        return SavedGame(id: 1, ref: ref, elapsedMs: elapsedMs, status: status, startedAt: 0)
    }

    @Test("given a date and size when the daily id is made then it matches Android's format")
    func dailyIdFormat() {
        // Act
        let id = PuzzleRef.dailyId(date: day, size: 8)

        // Assert
        #expect(id == "daily_2026-10-25_8")
    }

    @Test("given a date when the daily is picked twice then the puzzle is the same")
    func dailyIsStable() {
        // Act
        let first = PuzzleRef.daily(puzzles: bank, date: day, size: 3)
        let second = PuzzleRef.daily(puzzles: bank, date: day, size: 3)

        // Assert
        #expect(first == second)
    }

    @Test("given consecutive days across a full cycle when dailies are picked then every puzzle is used once")
    func dailyCyclesThroughBank() {
        // Act
        let picked = (0..<bank.count).map { PuzzleRef.daily(puzzles: bank, date: day.adding(days: $0), size: 3).puzzle.encode() }

        // Assert
        #expect(Set(picked).count == bank.count)
    }

    @Test("given a date before the first day when the daily is picked then the index still wraps into the bank")
    func dailyBeforeFirstDay() {
        // Act
        let ref = PuzzleRef.daily(puzzles: bank, date: day.adding(days: -1), size: 3)

        // Assert
        #expect(bank.contains(ref.puzzle))
    }

    @Test("given a seed when a random puzzle is picked then the id names its size and index", arguments: [Int64(1), 42, -7])
    func randomId(seed: Int64) {
        // Act
        let ref = PuzzleRef.random(puzzles: bank, size: 3, seed: seed)

        // Assert
        let index = Int(ref.id.split(separator: "_")[2])!
        #expect(ref.id.hasPrefix("bank_3_"))
        #expect(bank[index] == ref.puzzle)
    }

    @Test(
        "given a ref when its slot and title are read then dailies have their own",
        arguments: [
            ("daily_2026-10-25_3", "daily_2026-10-25_3", "Daily · 25 Oct · 3 x 3", true),
            ("bank_3_1", "size_3", "3 x 3", false),
        ])
    func slotAndTitle(id: String, slot: String, title: String, isDaily: Bool) {
        // Act
        let ref = PuzzleRef(id: id, puzzle: small)

        // Assert
        #expect(ref.slot == slot)
        #expect(ref.title == title)
        #expect(ref.isDaily == isDaily)
    }

    @Test("given finished and in-progress games when stats are made then in-progress is left out and abandoned counts as played")
    func stats() {
        // Arrange
        let games = [
            game(status: .solved, elapsedMs: 1000),
            game(status: .solved, elapsedMs: 2001),
            game(status: .abandoned),
            game(status: .revealed),
            game(status: .inProgress),
            game(size: 4, status: .solved),
        ]

        // Act
        let stats = SizeStats.of(size: 3, games: games)

        // Assert
        #expect(stats == SizeStats(size: 3, played: 4, solved: 2, bestMs: 1000, averageMs: 1500))
    }

    @Test("given no solved games when stats are made then best and average are empty")
    func emptyStats() {
        // Act
        let stats = SizeStats.of(size: 3, games: [game(status: .abandoned)])

        // Assert
        #expect(stats == SizeStats(size: 3, played: 1, solved: 0, bestMs: nil, averageMs: nil))
    }

    @Test(
        "given a duration when it is formatted then it matches Android",
        arguments: [(Int64(0), "0:00"), (65_000, "1:05"), (3_605_000, "1:00:05"), (36_610_999, "10:10:10")])
    func duration(ms: Int64, text: String) {
        // Act
        let formatted = formatDuration(ms: ms)

        // Assert
        #expect(formatted == text)
    }

    @Test("given a selected cell with a placed digit when combination lines are made then the placed digit is flagged")
    func combinationLines() {
        // Arrange
        let game = GameState(puzzle: small).tapCell(4).tapDigit(1)

        // Act
        let lines = game.combinationLines()

        // Assert
        #expect(lines[0].header == "Across 3 in 2: ")
        #expect(lines[0].sets == [[CombinationDigit(digit: 1, placed: true), CombinationDigit(digit: 2, placed: false)]])
        #expect(lines[1].header == "Down 4 in 2: ")
    }

    @Test("given a selected cell when run cells are read then both runs are included")
    func runCells() {
        // Act
        let cells = GameState(puzzle: small).tapCell(4).highlightedRunCells

        // Assert
        #expect(cells == [4, 5, 7])
    }

    @Test("given all needed copies of a digit placed when done digits are read then it is listed")
    func doneDigits() {
        // Act
        let done = GameState(puzzle: small).tapCell(4).tapDigit(1).doneDigits

        // Assert
        #expect(done == [1])
    }

    @Test("given an active digit when same-digit cells are read then cells holding it are listed")
    func sameDigit() {
        // Arrange
        let game = GameState(puzzle: small, inputMode: .digitFirst).tapDigit(1).tapCell(4)

        // Act
        let cells = game.sameDigitCells

        // Assert
        #expect(cells == [4])
    }
}
