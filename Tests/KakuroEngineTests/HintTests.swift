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

    @Test("given no cell that can be worked out when a hint is asked for then it names the cell's runs and candidates")
    func fallbackNamesCandidates() {
        // Arrange
        let game = GameState(puzzle: puzzle(3, "000 013 031"))

        // Act
        let hint = game.findHint()

        // Assert
        #expect(
            hint == Hint(cell: 4, digit: 1, message: "This cell's across run (4 in 2) and down run (4 in 2) only allow 1 or 3."))
        #expect(hint?.message.contains("first empty") == false)
    }

    @Test("given no cell can be worked out when the fallback hint is asked for then it names the runs and the digits they allow")
    func fewestCandidates() throws {
        // Act
        let hint = try #require(GameState(puzzle: small).fewestCandidatesHint())

        // Assert
        #expect(hint.cell == 4)
        #expect(hint.digit == 1)
        #expect(hint.message.contains("across run (3 in 2)"))
        #expect(hint.message.contains("down run (4 in 2)"))
        #expect(hint.message.hasSuffix("only allow 1."))
        #expect(!hint.message.contains("first empty"))
    }

    @Test("given a placed digit when the fallback hint is asked for then the cell's runs leave it out")
    func fewestCandidatesSkipsPlaced() throws {
        // Arrange
        let game = GameState(puzzle: small, values: [0, 0, 0, 0, 1, 0, 0, 0, 0])

        // Act
        let hint = try #require(game.fewestCandidatesHint())

        // Assert
        #expect(hint == Hint(cell: 5, digit: 2, message: "This cell's across run (3 in 2) and down run (6 in 2) only allow 2."))
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
