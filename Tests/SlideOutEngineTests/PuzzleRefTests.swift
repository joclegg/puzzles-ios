import PuzzlesCore
import Testing

@testable import SlideOutEngine

struct PuzzleRefTests {
    private let puzzles = (0..<7).map { index in
        Puzzle(board: Board(blocks: [Block(row: 2, col: 0, length: 2, horizontal: true)]), par: index + 1)
    }
    private let firstDay = CalendarDay(year: 2026, month: 10, day: 25)

    @Test("given a level when the daily id is made then it matches the web's lower case id")
    func dailyId() {
        // Act
        let id = PuzzleRef.dailyId(date: CalendarDay(year: 2026, month: 10, day: 30), level: .easy)

        // Assert
        #expect(id == "daily_2026-10-30_easy")
    }

    @Test("given a date and level when the daily is picked twice then it is the same puzzle")
    func dailyIsStable() {
        // Act
        let first = PuzzleRef.daily(puzzles: puzzles, date: firstDay, level: .hard)
        let second = PuzzleRef.daily(puzzles: puzzles, date: firstDay, level: .hard)

        // Assert
        #expect(first == second)
        #expect(first.isDaily)
        #expect(first.slot == first.id)
    }

    @Test("given a run of days as long as the bank when dailies are picked then none repeats")
    func dailiesCoverTheBank() {
        // Act
        let pars = puzzles.indices.map {
            PuzzleRef.daily(puzzles: puzzles, date: firstDay.adding(days: $0), level: .easy).puzzle.par
        }

        // Assert
        #expect(Set(pars).count == puzzles.count)
    }

    @Test("given a day before the first day when the daily is picked then it wraps into the bank")
    func dailyBeforeFirstDay() {
        // Act
        let wrapped = PuzzleRef.daily(puzzles: puzzles, date: firstDay.adding(days: -1), level: .easy)
        let last = PuzzleRef.daily(puzzles: puzzles, date: firstDay.adding(days: 6), level: .easy)

        // Assert
        #expect(wrapped.puzzle == last.puzzle)
    }

    @Test("given a random pick when it is made then its slot is the level")
    func randomSlot() {
        // Act
        let ref = PuzzleRef.random(puzzles: puzzles, level: .medium, seed: 42)

        // Assert
        #expect(ref.slot == "MEDIUM")
        #expect(ref.id.hasPrefix("bank_MEDIUM_"))
        #expect(!ref.isDaily)
    }

    @Test("given a daily when it is titled then it shows the date and level")
    func dailyTitle() {
        // Arrange
        let date = CalendarDay(year: 2026, month: 10, day: 5)

        // Act
        let title = PuzzleRef.daily(puzzles: puzzles, date: date, level: .easy).title

        // Assert
        #expect(title == "Daily · 5 Oct · Easy")
    }

    @Test(
        "given moves and par when the result is worded then par is called out",
        arguments: [(2, "2 moves, par!"), (3, "3 moves, par is 2")]
    )
    func movesText(moves: Int, expected: String) {
        // Act
        let text = solvedMovesText(moveCount: moves, par: 2)

        // Assert
        #expect(text == expected)
    }

    @Test(
        "given a time and previous best when compared then only a faster time or a first solve is a best",
        arguments: [(Int64(5), Int64?.none, true), (5, 6, true), (6, 6, false), (7, 6, false)]
    )
    func newBest(time: Int64, previous: Int64?, expected: Bool) {
        // Act
        let result = isNewBest(elapsedMs: time, previousBestMs: previous)

        // Assert
        #expect(result == expected)
    }

    @Test("given games of each status when stats are made then only finished games count as played")
    func stats() {
        // Arrange
        let games = [
            FinishedGame(level: .easy, status: .solved, moveCount: 10, par: 10, elapsedMs: 900),
            FinishedGame(level: .easy, status: .solved, moveCount: 12, par: 10, elapsedMs: 500),
            FinishedGame(level: .easy, status: .abandoned, moveCount: 1, par: 10, elapsedMs: 1),
            FinishedGame(level: .easy, status: .revealed, moveCount: 10, par: 10, elapsedMs: 2),
            FinishedGame(level: .easy, status: .inProgress, moveCount: 1, par: 10, elapsedMs: 3),
        ]

        // Act
        let stats = LevelStats.of(games)

        // Assert
        #expect(stats.count == Level.allCases.count)
        #expect(stats[1] == LevelStats(level: .easy, played: 4, solved: 2, atPar: 1, bestMs: 500))
        #expect(stats[0].bestMs == nil)
    }
}
