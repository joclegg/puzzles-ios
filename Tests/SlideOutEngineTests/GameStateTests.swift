import Testing

@testable import SlideOutEngine

private let puzzle = Puzzle(board: try! Board.decode("202H,033V"), par: 2)

struct GameStateTests {
    @Test("given the blocker moved and the red block slid out when the game is checked then it is solved in two moves")
    func solvedInTwo() {
        // Act
        let game = GameState(puzzle: puzzle).slide(1, to: 3).slide(0, to: 4)

        // Assert
        #expect(game.isSolved)
        #expect(game.moves.count == 2)
    }

    @Test("given one block slid twice in a row when moves are counted then it is one move")
    func mergesSlides() {
        // Act
        let game = GameState(puzzle: puzzle).slide(1, to: 2).slide(1, to: 3)

        // Assert
        #expect(game.moves == [Move(block: 1, position: 3)])
    }

    @Test("given a block slid away and straight back when moves are counted then it costs nothing")
    func slideBackCostsNothing() {
        // Act
        let game = GameState(puzzle: puzzle).slide(1, to: 3).slide(1, to: 0)

        // Assert
        #expect(game.moves.isEmpty)
    }

    @Test("given a slide past another block when it is tried then nothing moves")
    func blockedSlide() {
        // Act
        let game = GameState(puzzle: puzzle).slide(0, to: 4)

        // Assert
        #expect(game.moves.isEmpty)
    }

    @Test("given a puzzle when a hint is asked for then it is the first move of a shortest solution")
    func hint() {
        // Act
        let hint = GameState(puzzle: puzzle).withHint().hint

        // Assert
        #expect(hint == Move(block: 1, position: 3))
    }

    @Test("given moves saved and replayed when the board is rebuilt then it matches")
    func replay() throws {
        // Arrange
        let game = GameState(puzzle: puzzle).slide(1, to: 3)

        // Act
        let replayed = GameState(puzzle: puzzle, moves: try MoveCodec.decode(MoveCodec.encode(game.moves)))

        // Assert
        #expect(replayed.board == game.board)
    }
}
