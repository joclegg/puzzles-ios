import Testing

@testable import WordWheelEngine

private let words = WordList(valid: ["parade", "area", "pare", "drape", "rap", "dear"], common: ["parade", "area"])
private let puzzle = Puzzle(
    letters: "APARED",
    crossword: Crossword(placements: [
        Placement(word: "PARADE", row: 0, col: 0, across: true),
        Placement(word: "AREA", row: 0, col: 1, across: false),
    ])
)

struct GameStateTests {
    @Test(
        "given a guess when it is submitted then it is found, a bonus or refused",
        arguments: [
            ("area", Guess.found),
            ("pare", Guess.bonus),
            ("drape", Guess.bonus),
            ("zebra", Guess.notAWord),
            ("pa", Guess.tooShort),
            ("dread", Guess.notAWord),
        ]
    )
    func submit(word: String, expected: Guess) {
        // Act
        let after = GameState(puzzle: puzzle).submit(word, words: words)

        // Assert
        #expect(after.last == expected)
    }

    @Test("given a word already found when it is guessed again then it is marked as already found")
    func alreadyFound() {
        // Act
        let after = GameState(puzzle: puzzle).submit("area", words: words).submit("AREA", words: words)

        // Assert
        #expect(after.last == .already)
        #expect(after.found == ["AREA"])
    }

    @Test("given every crossword word found when the game is checked then it is solved")
    func solved() {
        // Act
        let after = GameState(puzzle: puzzle).submit("parade", words: words).submit("area", words: words)

        // Assert
        #expect(after.isSolved)
    }

    @Test("given a hint when a letter is revealed then the first hidden cell shows, and a word completed by hints counts as found")
    func hintsComplete() {
        // Arrange
        let game = GameState(puzzle: puzzle).submit("parade", words: words)

        // Act
        let after = (1...3).reduce(game) { state, _ in state.reveal { $0.first } }

        // Assert
        #expect(after.isSolved)
        #expect(after.found == ["PARADE", "AREA"])
    }

    @Test("given a word list when American only spellings are checked then they are left out of the common words")
    func americanOnly() {
        // Act
        let list = WordList(valid: ["color", "colour", "center", "centre", "tree"], common: ["color", "center", "tree"])

        // Assert
        #expect(list.common == ["TREE"])
    }

    @Test("given cells revealed out of order when they are read then they keep the order they were revealed in")
    func revealedOrder() {
        // Arrange
        let cells = [Cell(row: 3, col: 1), Cell(row: 1, col: 1), Cell(row: 2, col: 1)]

        // Act
        let after = cells.reduce(GameState(puzzle: puzzle)) { state, cell in state.reveal { _ in cell } }

        // Assert
        #expect(after.revealed == cells)
    }

    @Test("given a puzzle when every word is revealed then they are found in placement order")
    func revealAllOrder() {
        // Act
        let after = GameState(puzzle: puzzle).revealAll()

        // Assert
        #expect(after.found == ["PARADE", "AREA"])
    }
}
