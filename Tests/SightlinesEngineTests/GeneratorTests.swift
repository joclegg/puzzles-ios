import PuzzlesCore
import Testing

@testable import SightlinesEngine

struct GeneratorTests {
    @Test(
        "given a size when a puzzle is generated then numbers are right and at most the grid size, and logic solves it",
        arguments: [4, 5, 6, 7, 8, 9]
    )
    func generated(size: Int) {
        // Act
        let puzzle = Generator.generate(size: size, seed: Int64(size))

        // Assert
        let solution = puzzle.solution
        let blues = solution.dots.indices.filter { solution.dots[$0] == .blue }
        #expect(puzzle.brokenCells(solution).isEmpty)
        #expect(blues.allSatisfy { solution.seen($0) > 0 })
        #expect(puzzle.numbers.allSatisfy { solution.seen($0.key) == $0.value })
        #expect(blues.allSatisfy { solution.seen($0) <= size })
        #expect(Solver.solveLogically(puzzle.givens, numbers: puzzle.numbers) == solution)
    }

    @Test("given a puzzle when it is encoded and decoded then it is unchanged", arguments: [Int64(1), 2, 3])
    func codecRoundTrip(seed: Int64) {
        // Arrange
        let puzzle = Generator.generate(size: 9, seed: seed)

        // Act
        let decoded = Puzzle.decode(puzzle.encode())

        // Assert
        #expect(decoded == puzzle)
    }

    @Test(
        "given a date and size when the daily puzzle is generated then it matches Android",
        arguments: [
            (4, "4;..X...X.44.24..X;BBRBBBRBBBRBBBRR"),
            (6, "6;.4......4.43..2...11.2.X..X..X.X....;BBBBRBBBBRBBRRBRBBBBRBBRRRRBBRRRRRRR"),
            (
                8,
                "8;X....X....22..6.X.4.....2....7.5..4...6......6...6..8..1...X.4..;RRRRRRRRRRBBRBBBRBBBBRBBBRRRBBBBBBBRBBBRBBBRBBBRRBBBBBRBRRRRRBRB"
            ),
            (
                9,
                "9;3...X.X...3...X...3..7...126....X.....8.....1..7..X..1X1.8.......X...4......3.5.3;BRBRRRRRRBBBBRRRRBBRBBBRRBBBBBBRRRRRRRBBBBRRBRBBBRRBRBRBRBBBBRRRRRRRBBRBRBBBBRBBB"
            ),
        ]
    )
    func dailyMatchesAndroid(size: Int, encoded: String) {
        // Act
        let puzzle = Generator.daily(date: CalendarDay(year: 2026, month: 10, day: 25), size: size)

        // Assert
        #expect(puzzle.encode() == encoded)
    }

    @Test("given a negative seed when a puzzle is generated then it matches Android")
    func negativeSeedMatchesAndroid() {
        // Act
        let puzzle = Generator.generate(size: 6, seed: -1)

        // Assert
        #expect(puzzle.encode() == "6;.2X.4....3.......1....6.1.2......22.;BBRRBBRBBBBRRRRRBBRBBBBRBRBRRRBRBBBR")
    }
}
