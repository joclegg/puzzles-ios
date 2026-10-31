import Testing

@testable import TwoToneEngine

private func grid(_ text: String) -> Grid {
    Grid.parse(size: 4, text: text)!
}

struct GameStateTests {
    private let solution = grid("RBBR BRRB RBRB BRBR")
    private var puzzle: Puzzle {
        Puzzle(givens: grid("R... .... .... ...."), solution: solution)
    }

    @Test("given an empty tile when it is tapped three times then it goes red, blue and empty again")
    func tapCycles() {
        // Arrange
        let game = GameState(puzzle: puzzle)

        // Act
        let first = game.tap(1)
        let second = first.tap(1)
        let third = second.tap(1)

        // Assert
        #expect(
            [game, first, second, third].map { $0.grid.tiles[1] } == [.empty, .red, .blue, .empty]
        )
    }

    @Test("given a starting tile when it is tapped then it does not change")
    func tapGiven() {
        // Act
        let after = GameState(puzzle: puzzle).tap(0)

        // Assert
        #expect(after.grid.tiles[0] == .red)
    }

    @Test("given several taps when they are all undone then the grid is back to the start", arguments: [1, 4, 9])
    func undoAll(taps: Int) {
        // Arrange
        let played = (1...taps).reduce(GameState(puzzle: puzzle)) { state, tap in state.tap(tap % 15 + 1) }

        // Act
        let undone = (1...taps).reduce(played) { state, _ in state.undo() }

        // Assert
        #expect(undone.grid == puzzle.givens)
    }

    @Test("given taps saved as changes when the game is replayed then the grid matches")
    func replay() {
        // Arrange
        let played = GameState(puzzle: puzzle).tap(1).tap(1).tap(5)

        // Act
        let replayed = GameState.replay(puzzle: puzzle, changes: ChangeCodec.decode(ChangeCodec.encode(played.changes))!)

        // Assert
        #expect(replayed.grid == played.grid)
    }

    @Test("given a wrong tile when a hint is asked for then the wrong tile is pointed out")
    func hintMistake() {
        // Arrange
        let game = GameState(puzzle: puzzle).tap(1)

        // Act
        let hint = game.withHint().hint

        // Assert
        #expect(hint == .mistake(cells: [1]))
    }

    @Test("given no mistakes when a hint is asked for then the next deduction is given")
    func hintNext() {
        // Arrange
        let game = GameState(
            puzzle: Puzzle(givens: grid("RR.. .... .... ...."), solution: grid("RRBB BBRR RBRB BRBR"))
        )

        // Act
        let hint = game.withHint().hint

        // Assert
        guard case .next(let deduction, _) = hint else {
            Issue.record("Expected a next hint")
            return
        }
        #expect(deduction.cells == [2])
    }

    @Test("given the last tile when it is filled correctly then the puzzle is solved")
    func lastTile() {
        // Arrange
        let game = GameState(puzzle: puzzle, grid: solution.with(cell: 1, tile: .empty))

        // Act
        let after = game.tap(1).tap(1)

        // Assert
        #expect(after.isSolved)
        #expect(after.progressPercent == 100)
    }

    @Test(
        "given a colour picked when an empty spot is painted twice then it takes the colour and then clears",
        arguments: [Tile.red, Tile.blue]
    )
    func paintTwice(colour: Tile) {
        // Arrange
        let game = GameState(puzzle: puzzle)

        // Act
        let painted = game.paint(1, colour: colour)
        let cleared = painted.paint(1, colour: colour)

        // Assert
        #expect(painted.grid.tiles[1] == colour)
        #expect(cleared.grid.tiles[1] == .empty)
    }

    @Test("given a spot of one colour when it is painted the other colour then it switches in one undoable change")
    func paintSwitch() {
        // Arrange
        let game = GameState(puzzle: puzzle).paint(1, colour: .red)

        // Act
        let after = game.paint(1, colour: .blue)

        // Assert
        #expect(after.grid.tiles[1] == .blue)
        #expect(after.undo().grid.tiles[1] == .red)
    }

    @Test("given a starting spot when it is painted then it does not change")
    func paintGiven() {
        // Act
        let after = GameState(puzzle: puzzle).paint(0, colour: .blue)

        // Assert
        #expect(after.grid == puzzle.givens)
    }
}
