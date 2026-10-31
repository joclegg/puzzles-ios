import Testing

@testable import SlideOutEngine

struct SolverTests {
    @Test("given a blocker in the way when the shortest solution is found then it moves the blocker then the red block")
    func movesBlockerThenRed() throws {
        // Arrange
        let board = try Board.decode("202H,033V")

        // Act
        let moves = Solver.shortest(board)

        // Assert
        #expect(moves == [Move(block: 1, position: 3), Move(block: 0, position: 4)])
    }

    @Test("given a red block walled in when it is solved then there is no solution")
    func walledIn() throws {
        // Act
        let moves = Solver.shortest(try Board.decode("202H,232H"))

        // Assert
        #expect(moves == nil)
    }
}
