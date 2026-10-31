import PuzzlesCore
import Testing

@testable import SightlinesEngine

struct SavedGameTests {
    private let day = CalendarDay(year: 2026, month: 3, day: 7)
    private let puzzle = Puzzle.decode("4;................;BBRBBRBBRBBRBBRR")!

    private func game(id: Int64, status: GameStatus, elapsed: Int64 = 0, refId: String = "random_1") -> SavedGame {
        SavedGame(id: id, ref: PuzzleRef(id: refId, puzzle: puzzle), elapsedMs: elapsed, status: status, startedAt: 0)
    }

    @Test(
        "given a duration when formatted then hours only show when needed",
        arguments: [(Int64(0), "0:00"), (65_000, "1:05"), (3_725_000, "1:02:05")]
    )
    func duration(ms: Int64, text: String) {
        // Act
        let result = formatDuration(ms: ms)

        // Assert
        #expect(result == text)
    }

    @Test("given a daily ref when read then its slot and title name the date")
    func dailyRef() {
        // Arrange
        let ref = PuzzleRef(id: PuzzleRef.dailyId(date: day, size: 4), puzzle: puzzle)

        // Assert
        #expect(ref.id == "daily_2026-03-07_4")
        #expect(ref.isDaily)
        #expect(ref.slot == ref.id)
        #expect(ref.title == "Daily · 7 Mar · 4 x 4")
    }

    @Test("given a random ref when read then its slot is its size")
    func randomRef() {
        // Arrange
        let ref = PuzzleRef(id: "random_5", puzzle: puzzle)

        // Assert
        #expect(ref.slot == "size_4")
        #expect(ref.title == "4 x 4")
    }

    @Test("given finished games when counted then abandoned count as played and only solved count for times")
    func stats() {
        // Arrange
        let games = [
            game(id: 1, status: .solved, elapsed: 1000),
            game(id: 2, status: .solved, elapsed: 2001),
            game(id: 3, status: .abandoned, elapsed: 5),
            game(id: 4, status: .revealed, elapsed: 5),
            game(id: 5, status: .inProgress, elapsed: 5),
        ]

        // Act
        let result = games.stats(size: 4)

        // Assert
        #expect(result == SizeStats(size: 4, played: 4, solved: 2, bestMs: 1000, averageMs: 1500))
    }

    @Test(
        "given a previous best when a game finishes then only a faster time is a new best",
        arguments: [(Int64(999), true), (1000, false), (1001, false)]
    )
    func newBest(elapsed: Int64, expected: Bool) {
        // Arrange
        let finished = game(id: 2, status: .solved, elapsed: elapsed)
        let games = [game(id: 1, status: .solved, elapsed: 1000), finished]

        // Act
        let result = games.isNewBest(finished)

        // Assert
        #expect(result == expected)
    }

    @Test("given no other solved game when a game finishes then it is a new best")
    func firstBest() {
        // Arrange
        let finished = game(id: 1, status: .solved, elapsed: 9)

        // Act
        let result = [finished].isNewBest(finished)

        // Assert
        #expect(result)
    }

    @Test("given games when looking for saves then dailies stay out of the size slot")
    func saves() {
        // Arrange
        let dailyId = PuzzleRef.dailyId(date: day, size: 4)
        let games = [game(id: 1, status: .inProgress, refId: dailyId), game(id: 2, status: .inProgress), game(id: 3, status: .solved)]

        // Act
        let saved = games.savedGame(forSize: 4)
        let daily = games.dailyInProgress(date: day, size: 4)

        // Assert
        #expect(saved?.id == 2)
        #expect(daily?.id == 1)
        #expect(games.inProgress.count == 2)
    }

    @Test("given a solved daily when asked for today's then only that size counts")
    func dailySolved() {
        // Arrange
        let games = [
            game(id: 1, status: .solved, refId: PuzzleRef.dailyId(date: day, size: 4)),
            game(id: 2, status: .abandoned, refId: PuzzleRef.dailyId(date: day, size: 5)),
            game(id: 3, status: .solved, refId: PuzzleRef.dailyId(date: day.adding(days: 1), size: 6)),
        ]

        // Act
        let result = games.dailySolved(date: day)

        // Assert
        #expect(result == [4])
    }

    @Test(
        "given mistakes when a hint explains them then the wording follows the count",
        arguments: [([1], "This dot is the wrong colour."), ([1, 2, 3], "These 3 dots are the wrong colour.")]
    )
    func mistakeMessage(cells: [Int], message: String) {
        // Act
        let result = Hint.mistake(cells: cells).message

        // Assert
        #expect(result == message)
    }

    @Test("given a hint when the board asks then a next step shades sight and a mistake only marks targets")
    func hintCells() {
        // Arrange
        let deduction = Deduction(cells: [1], dot: .red, reason: .alone, source: 0)
        let next = GameState(puzzle: puzzle, hint: .next(deduction: deduction, cells: [0, 1, 2]))
        let mistake = GameState(puzzle: puzzle, hint: .mistake(cells: [5]))

        // Assert
        #expect(next.hintSight == [0, 1, 2])
        #expect(next.hintTargets == [1])
        #expect(mistake.hintSight.isEmpty)
        #expect(mistake.hintTargets == [5])
    }

    @Test("given a cell when tagged then row and column are one-based")
    func tag() {
        // Act
        let result = dotTag(cell: 5, size: 4)

        // Assert
        #expect(result == "dot_r2c2")
    }
}
