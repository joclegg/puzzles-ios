import Testing

@testable import KakuroEngine

struct HintTests {
    @Test("given a fresh puzzle when a hint is asked for then it points at the cell where only one digit fits")
    func onlyDigit() {
        // Act
        let hint = GameState(puzzle: small).findHint()

        // Assert
        #expect(hint == Hint(cell: 4, digit: 1, message: "Only 1 fits here: 3 in 2 across and 4 in 2 down leave no other digit."))
    }

    @Test("given a wrong digit when a hint is asked for then it points at that cell first")
    func wrongFirst() {
        // Arrange
        let game = GameState(puzzle: small, values: [0, 0, 0, 0, 0, 0, 0, 0, 9])

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint?.message == "This cell is wrong.")
    }

    @Test("given a hint when it is placed then the cell holds its answer")
    func placeHint() throws {
        // Arrange
        let game = GameState(puzzle: small)

        // Act
        let placed = game.placeHint(try #require(game.findHint()))

        // Assert
        #expect(placed.values[4] == 1)
    }

    @Test("given a puzzle when the solution is revealed then every cell holds its answer")
    func reveal() {
        // Act
        let revealed = GameState(puzzle: small).revealSolution()

        // Assert
        #expect(revealed.values == small.solution)
    }
}
