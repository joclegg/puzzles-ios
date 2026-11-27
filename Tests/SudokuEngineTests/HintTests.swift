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

    @Test("given no cell that can be worked out when a hint is asked for then it names the cell's candidates")
    func fallbackNamesCandidates() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        let empty = GameState(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution))

        // Act
        let hint = try #require(empty.findHint())

        // Assert
        #expect(hint.cell == 0)
        #expect(hint.digit == solution[0])
        #expect(hint.message == "This cell can only be 1, 2, 3, 4, 5, 6, 7, 8 or 9: everything else is in its row, column or box.")
        #expect(!hint.message.contains("first empty"))
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

    @Test("given notes that match a cell's candidates when a hint is asked for then the fallback skips that cell")
    func fallbackSkipsMatchingNotes() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        var notes = Array(repeating: 0, count: 81)
        notes[0] = (1...9).reduce(0) { $0 | digitBit($1) }
        let state = GameState(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution), notes: notes)

        // Act
        let hint = try #require(state.findHint())

        // Assert
        #expect(hint.cell == 1)
        #expect(hint.message.hasPrefix("This cell can only be"))
    }

    @Test("given notes tighter than a cell's candidates when a hint is asked for then the fallback skips that cell")
    func fallbackSkipsTighterNotes() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        var notes = Array(repeating: 0, count: 81)
        notes[0] = digitBit(solution[0])
        let state = GameState(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution), notes: notes)

        // Act
        let hint = try #require(state.findHint())

        // Assert
        #expect(hint.cell == 1)
    }

    @Test("given every empty cell noted within its candidates when a hint is asked for then it reveals a cell's answer")
    func fallbackRevealsWhenAllNoted() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        let notes = Array(repeating: (1...9).reduce(0) { $0 | digitBit($1) }, count: 81)
        let state = GameState(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution), notes: notes)

        // Act
        let hint = try #require(state.findHint())

        // Assert
        #expect(hint == Hint(cell: 0, digit: solution[0], message: "This one is the \(solution[0])."))
    }

    @Test("given notes wider than a cell's candidates when a hint is asked for then the fallback still names that cell")
    func fallbackKeepsWiderNotes() throws {
        // Arrange
        let solution = try #require(easyPuzzle.solution)
        var values = Array(repeating: 0, count: 81)
        values[1] = solution[1]
        var notes = Array(repeating: 0, count: 81)
        notes[0] = (1...9).reduce(0) { $0 | digitBit($1) }
        let state = GameState(
            puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution), values: values, notes: notes)

        // Act
        let hint = try #require(state.findHint())

        // Assert
        #expect(hint.cell == 0)
        #expect(hint.digit == solution[0])
        #expect(!hint.message.contains("\(solution[1])"))
    }
}
