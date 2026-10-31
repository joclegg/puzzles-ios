import Testing

@testable import SightlinesEngine

struct GameStateTests {
    private let solution = Grid.parse(size: 4, text: "BBRB BRBB RBBR BBRB")!
    private var puzzle: Puzzle {
        Puzzle(solution: solution, numbers: [0: 2], walls: [2])
    }

    @Test("given an empty dot when it is tapped three times then it goes blue, red and empty again")
    func tapCycles() {
        // Arrange
        let game = GameState(puzzle: puzzle)

        // Act
        let first = game.tap(1)
        let second = first.tap(1)
        let third = second.tap(1)

        // Assert
        #expect(
            [game, first, second, third].map { $0.grid.dots[1] } == [.empty, .blue, .red, .empty]
        )
    }

    @Test("given a starting dot when it is tapped then it does not change", arguments: [0, 2])
    func tapGiven(cell: Int) {
        // Act
        let after = GameState(puzzle: puzzle).tap(cell)

        // Assert
        #expect(after.grid.dots[cell] == puzzle.givens.dots[cell])
    }

    @Test("given taps saved as changes when the game is replayed then the grid matches")
    func replay() {
        // Arrange
        let played = GameState(puzzle: puzzle).tap(1).tap(5).tap(5)

        // Act
        let replayed = GameState.replay(puzzle: puzzle, changes: ChangeCodec.decode(ChangeCodec.encode(played.changes))!)

        // Assert
        #expect(replayed.grid == played.grid)
    }

    @Test("given a wrong dot when a hint is asked for then the wrong dot is pointed out")
    func hintMistake() {
        // Arrange
        let game = GameState(puzzle: puzzle).tap(1).tap(1)

        // Act
        let hint = game.withHint().hint

        // Assert
        #expect(hint == .mistake(cells: [1]))
    }

    @Test("given no mistakes when a hint is asked for then the next deduction is given with the number's lines of sight")
    func hintNext() {
        // Act
        let hint = GameState(puzzle: puzzle).withHint().hint

        // Assert
        guard case .next(let deduction, let cells) = hint else {
            Issue.record("Expected a next hint")
            return
        }
        #expect(deduction.source == 0)
        #expect(cells.contains(0) && cells.contains(12))
    }

    @Test("given a number boxed in by red dots when broken dots are found then it is listed")
    func boxedIn() {
        // Arrange
        let game = GameState(puzzle: puzzle).tap(1).tap(1).tap(4).tap(4)

        // Act
        let broken = game.brokenCells

        // Assert
        #expect(broken == [0])
    }

    @Test("given the last dot when it is set right then the puzzle is solved")
    func lastDot() {
        // Arrange
        let game = GameState(puzzle: puzzle, grid: solution.with(cell: 1, dot: .empty))

        // Act
        let after = game.tap(1)

        // Assert
        #expect(after.isSolved)
    }

    @Test(
        "given a colour picked when an empty spot is painted twice then it takes the colour and then clears",
        arguments: [Dot.red, Dot.blue]
    )
    func paintTwice(colour: Dot) {
        // Arrange
        let game = GameState(puzzle: puzzle)

        // Act
        let painted = game.paint(1, colour: colour)
        let cleared = painted.paint(1, colour: colour)

        // Assert
        #expect(painted.grid.dots[1] == colour)
        #expect(cleared.grid.dots[1] == .empty)
    }

    @Test("given a spot of one colour when it is painted the other colour then it switches in one undoable change")
    func paintSwitch() {
        // Arrange
        let game = GameState(puzzle: puzzle).paint(1, colour: .blue)

        // Act
        let after = game.paint(1, colour: .red)

        // Assert
        #expect(after.grid.dots[1] == .red)
        #expect(after.undo().grid.dots[1] == .blue)
    }

    @Test("given a starting spot when it is painted then it does not change")
    func paintGiven() {
        // Act
        let after = GameState(puzzle: puzzle).paint(0, colour: .red)

        // Assert
        #expect(after.grid == puzzle.givens)
    }
}
