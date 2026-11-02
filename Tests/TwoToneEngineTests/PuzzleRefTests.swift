import PuzzlesCore
import Testing

@testable import TwoToneEngine

struct PuzzleRefTests {
    @Test("given a date when a daily id is made then it carries the date and size")
    func dailyId() {
        // Arrange
        let date = CalendarDay(year: 2026, month: 3, day: 7)

        // Act
        let id = PuzzleRef.dailyId(date: date, size: 6)

        // Assert
        #expect(id == "daily_2026-03-07_6")
        #expect(PuzzleRef.isDaily(id: id))
        #expect(PuzzleRef.title(id: id, size: 6) == "Daily · 7 Mar · 6 x 6")
    }

    @Test(
        "given a puzzle id when its slot is read then dailies keep their own and others share by size",
        arguments: [
            ("daily_2026-03-07_6", "daily_2026-03-07_6"),
            ("random_12", "size_6"),
            ("fixture_two_tone_one_left", "size_6"),
        ]
    )
    func slot(id: String, slot: String) {
        // Act
        let result = PuzzleRef.slot(id: id, size: 6)

        // Assert
        #expect(result == slot)
    }

    @Test("given finished games when stats are made then only that size's finished games count")
    func stats() {
        // Arrange
        let games: [(size: Int, status: GameStatus, elapsedMs: Int64)] = [
            (6, .solved, 1000),
            (6, .solved, 3000),
            (6, .abandoned, 500),
            (6, .revealed, 400),
            (6, .inProgress, 100),
            (8, .solved, 50),
        ]

        // Act
        let stats = SizeStats.of(size: 6, games: games)

        // Assert
        #expect(stats == SizeStats(size: 6, played: 4, solved: 2, bestMs: 1000, averageMs: 2000))
    }

    @Test("given no solved games when stats are made then best and average are empty")
    func emptyStats() {
        // Act
        let stats = SizeStats.of(size: 4, games: [(4, .abandoned, 500)])

        // Assert
        #expect(stats == SizeStats(size: 4, played: 1, solved: 0, bestMs: nil, averageMs: nil))
    }

    @Test("given a wrong tile when hinted then the marks outline only that tile and the message is singular")
    func mistakeMarks() {
        // Arrange
        let solution = Grid.parse(size: 4, text: "RBBR BRRB RBRB BRBR")!
        let puzzle = Puzzle(givens: solution.with(cell: 1, tile: .empty), solution: solution)

        // Act
        let state = GameState(puzzle: puzzle).tap(1).withHint()
        let marks = state.boardMarks(markBrokenRules: false)

        // Assert
        #expect(marks.hintTargets == [1])
        #expect(marks.hintLine.isEmpty)
        #expect(marks.broken.isEmpty)
        #expect(!marks.givens.contains(1))
        #expect(state.hint?.message == "This tile is the wrong colour.")
    }

    @Test("given a logical step when hinted then the marks shade its line and outline its tiles")
    func nextMarks() {
        // Arrange
        let solution = Grid.parse(size: 4, text: "RBBR BRRB RBRB BRBR")!
        let puzzle = Puzzle(givens: solution.with(cell: 1, tile: .empty), solution: solution)

        // Act
        let marks = GameState(puzzle: puzzle).withHint().boardMarks(markBrokenRules: true)

        // Assert
        #expect(marks.hintTargets == [1])
        #expect(marks.hintLine.contains(1))
        #expect(marks.hintLine.count == 4)
    }
}
