import Testing

@testable import SudokuEngine

private let gradedPuzzles: [(String, Difficulty?)] = [
    (easyGivens, .easy),
    ("800000000003600000070090000050007000000045700000100030001000068008500000000000400", nil),
]

struct GraderTests {
    @Test(
        "given a puzzle when it is graded then it gets the level of its hardest technique",
        arguments: gradedPuzzles
    )
    func gradedLevel(givens: String, expectedLevel: Difficulty?) {
        // Arrange
        var grader = Grader(givens: digits(givens))

        // Act
        let grade = grader.grade()

        // Assert
        #expect(grade.level == expectedLevel)
    }

    @Test("given an easy puzzle when it is graded then the logical solve finds the solution")
    func logicalSolve() {
        // Arrange
        var grader = Grader(givens: digits(easyGivens))

        // Act
        grader.grade()

        // Assert
        #expect(grader.values == digits(easySolution))
    }
}
