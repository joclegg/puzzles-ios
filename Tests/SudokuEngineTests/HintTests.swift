import Testing

@testable import SudokuEngine

private let game = GameState(puzzle: easyPuzzle)

struct HintTests {
    @Test("given a fresh puzzle when a hint is asked for then it names a cell and its answer")
    func freshHint() throws {
        // Act
        let hint = try #require(game.findHint())

        // Assert
        #expect(easyPuzzle.solution?[hint.cell] == hint.digit)
    }

    @Test("given a wrong digit when a hint is asked for then it points at that cell first")
    func wrongDigitHint() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        let cell = try #require(easyPuzzle.givens.firstIndex(of: 0))
        var values = game.values
        values[cell] = solution[cell] % 9 + 1
        let wrong = GameState(puzzle: easyPuzzle, values: values)

        // Act
        let hint = wrong.findHint()

        // Assert
        #expect(hint == Hint(cell: cell, digit: solution[cell], message: "This cell is wrong."))
    }

    @Test("given a hint when it is placed then the cell holds its answer")
    func placeHint() throws {
        // Arrange
        let hint = try #require(game.findHint())

        // Act
        let placed = game.placeHint(hint)

        // Assert
        #expect(placed.values[hint.cell] == hint.digit)
    }
}
