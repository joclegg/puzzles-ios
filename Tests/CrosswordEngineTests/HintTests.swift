import Testing

@testable import CrosswordEngine

struct HintTests {
    private func state(_ entries: String, selected: Int, across: Bool = true) -> GameState {
        var state = GameState.start(puzzle: small, entries: Array(entries))
        state.selected = selected
        state.isAcross = across
        return state
    }

    @Test("given a wrong letter and empty cells when a hint is found then the wrong letter is hinted")
    func wrongBeatsEmpty() {
        // Arrange
        let game = state("C.X.#....", selected: 0)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint == Hint(cell: 2, letter: "T", message: "This letter is wrong."))
    }

    @Test("given several wrong letters when a hint is found then the first in reading order is hinted")
    func firstWrongInReadingOrder() {
        // Arrange
        let game = state("CAT.#XBO.", selected: 6)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint?.cell == 5)
        #expect(hint?.letter == "O")
    }

    @Test(
        "given an empty cell in the current word when a hint is found then that cell is hinted",
        arguments: [(0, true, 1), (6, false, 3), (8, true, 6)])
    func emptyInCurrentWord(selected: Int, across: Bool, cell: Int) {
        // Arrange
        let game = state("C.T.#....", selected: selected, across: across)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint?.cell == cell)
    }

    @Test("given the current word is full when a hint is found then the next clue's first empty cell is hinted")
    func nextClueWhenFull() {
        // Arrange
        let game = state("CAT.#....", selected: 0)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint == Hint(cell: 6, letter: "B", message: "Try B here."))
    }

    @Test("given the last clue is full when a hint is found then the search wraps to the first clue")
    func wrapsToFirstClue() {
        // Arrange
        let game = state("C.TA#OBOW", selected: 2, across: false)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint?.cell == 1)
    }

    @Test("given a full correct grid when a hint is found then there is none")
    func noHintWhenSolved() {
        // Arrange
        let game = state("CATA#OBOW", selected: 0)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint == nil)
    }

    @Test("given a wrong letter when a hint is placed then undo restores the wrong letter")
    func placeThenUndo() throws {
        // Arrange
        let game = state("C.X.#....", selected: 0)
        let hint = try #require(game.findHint())

        // Act
        let placed = game.placeHint(hint)
        let undone = placed.undo()

        // Assert
        #expect(String(placed.entries) == "C.T.#....")
        #expect(placed.selected == 2)
        #expect(placed.hints == 1)
        #expect(String(undone.entries) == "C.X.#....")
    }

    @Test("given a hint when it is pointed at then the cell is selected and the hints count goes up")
    func pointSelects() throws {
        // Arrange
        let game = state("CAT.#....", selected: 0)
        let hint = try #require(game.findHint())

        // Act
        let pointed = game.pointHint(hint)

        // Assert
        #expect(pointed.selected == 6)
        #expect(pointed.hints == 1)
        #expect(pointed.entries == game.entries)
    }
}
