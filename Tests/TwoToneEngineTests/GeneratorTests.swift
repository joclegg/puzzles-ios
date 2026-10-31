import PuzzlesCore
import Testing

@testable import TwoToneEngine

struct GeneratorTests {
    @Test(
        "given a size when a puzzle is generated then its solution follows every rule and logic alone solves it",
        arguments: [4, 6, 8, 10, 12]
    )
    func generated(size: Int) {
        // Act
        let puzzle = Generator.generate(size: size, seed: Int64(size))

        // Assert
        #expect(puzzle.solution.brokenCells().isEmpty)
        #expect(puzzle.solution.isFull)
        #expect(Solver.solveLogically(puzzle.givens) == puzzle.solution)
    }

    @Test("given a seed when two puzzles are generated then they match", arguments: [Int64(1), 2, 3])
    func repeatable(seed: Int64) {
        // Act
        let puzzles = [Generator.generate(size: 6, seed: seed), Generator.generate(size: 6, seed: seed)]

        // Assert
        #expect(puzzles[0] == puzzles[1])
    }

    @Test(
        "given a date and size when the daily puzzle is generated then it matches Android",
        arguments: [
            (4, "4;...B..RB.B....R.;RRBBBRRBRBBRBBRR"),
            (6, "6;...R....B....R.........BBR.....R..RR;RBRRBBRBBRBRBRRBRBRBRBRBBRBRBRBRBBRR"),
            (
                8,
                "8;..B.BB..B.......B.B.......B.BB.B............R.R.B.B.B...R.......;RBBRBBRRBBRBRRBRBRBRRBRBRRBRBBRBRBRBBRBRBRRBRBRBBRBRBRBRRBRBRRBB"
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
        #expect(puzzle.encode() == "6;..BB...R...R........B....R......B...;RRBBRBBRRBBRBBRRBRRBBRRBBRRBRBRBBRBR")
    }

    @Test("given a puzzle when it is encoded and decoded then it is unchanged")
    func codecRoundTrip() {
        // Arrange
        let puzzle = Generator.generate(size: 6, seed: 1)

        // Act
        let decoded = Puzzle.decode(puzzle.encode())

        // Assert
        #expect(decoded == puzzle)
    }
}
