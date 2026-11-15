import Testing

@testable import CrosswordEngine

struct GameStateTests {
    private func typed(_ state: GameState, _ letters: String) -> GameState {
        letters.reduce(state) { $0.type($1) }
    }

    private func entries(_ state: GameState) -> String {
        String(state.entries)
    }

    @Test("given a new game when it starts then the first across cell is selected")
    func startsOnFirstClue() {
        // Act
        let state = GameState.start(puzzle: small)

        // Assert
        #expect(state.selected == 0)
        #expect(state.isAcross)
        #expect(state.currentWord?.label == "1 Across")
    }

    @Test("given a saved grid when the game starts then the first clue with an empty cell is selected")
    func resumesOnFirstEmptyClue() {
        // Act
        let state = GameState.start(puzzle: small, entries: Array("CATA#OBO."))

        // Assert
        #expect(state.selected == 8)
        #expect(state.currentWord?.label == "3 Across")
    }

    @Test("given C A T typed then three backspaces clear T, A and C in turn and leave the cursor on C")
    func typeThenBackspace() {
        // Arrange
        let start = GameState.start(puzzle: small)

        // Act
        let afterC = start.type("c")
        let afterA = afterC.type("A")
        let afterT = afterA.type("T")
        let first = afterT.backspace()
        let second = first.backspace()
        let third = second.backspace()

        // Assert
        #expect(afterC.selected == 1)
        #expect(afterA.selected == 2)
        #expect(entries(afterT) == "CAT.#....")
        #expect(afterT.selected == 6)
        #expect(entries(first) == "CA..#....")
        #expect(first.selected == 2)
        #expect(first.isAcross)
        #expect(entries(second) == "C...#....")
        #expect(second.selected == 1)
        #expect(entries(third) == "....#....")
        #expect(third.selected == 0)
    }

    @Test("given a jump over a full clue when backspace follows then the letter just typed clears")
    func backspaceAfterJumpOverFullClue() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries = Array("CA.A#.BOW")
        state = state.tapCell(2)

        // Act
        let jumped = state.type("T")
        let cleared = jumped.backspace()
        let again = cleared.backspace()

        // Assert
        #expect(jumped.currentWord?.label == "2 Down")
        #expect(jumped.selected == 5)
        #expect(cleared.selected == 2)
        #expect(cleared.isAcross)
        #expect(cleared.entries[2] == emptyMark)
        #expect(cleared.jumpedFrom == nil)
        #expect(again.selected == 1)
        #expect(again.entries[1] == emptyMark)
    }

    @Test("given a jump when any other input comes before backspace then backspace follows the normal rules")
    func otherInputForgetsJump() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries = Array("CA.A#O..W")
        let jumped = state.tapCell(2).type("T")

        // Act
        let afterTap = jumped.tapCell(7).backspace()
        let afterArrow = jumped.arrow(.right).backspace()

        // Assert
        #expect(jumped.selected == 6)
        #expect(jumped.jumpedFrom == 2)
        #expect(afterTap.selected == 6)
        #expect(afterTap.entries[2] == "T")
        #expect(afterArrow.selected == 6)
        #expect(afterArrow.entries[2] == "T")
    }

    @Test("given a filled cell when backspace is pressed then it clears and the cursor stays")
    func backspaceClearsInPlace() {
        // Arrange
        let state = typed(GameState.start(puzzle: small), "CA").tapCell(1)

        // Act
        let next = state.backspace()

        // Assert
        #expect(next.selected == 1)
        #expect(next.entries[1] == emptyMark)
        #expect(next.entries[0] == "C")
    }

    @Test("given an empty cell mid-word when backspace is pressed then the previous cell clears in one press")
    func backspaceMovesBackAndClears() {
        // Arrange
        let state = typed(GameState.start(puzzle: small), "CA")

        // Act
        let next = state.backspace()

        // Assert
        #expect(next.selected == 1)
        #expect(next.entries[1] == emptyMark)
        #expect(next.entries[0] == "C")
        #expect(next.changes.count == 3)
    }

    @Test("given the empty first cell of the first clue when backspace is pressed then it wraps to the last clue")
    func backspaceWrapsToLastClue() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries[8] = "W"

        // Act
        let next = state.backspace()

        // Assert
        #expect(next.currentWord?.label == "2 Down")
        #expect(next.selected == 8)
        #expect(next.entries[8] == emptyMark)
    }

    @Test("given skip filled cells on when typing then the cursor jumps over filled cells")
    func skipFilledCells() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries[1] = "A"

        // Act
        let skipping = state.type("C")
        state.skipFilledCells = false
        let stepping = state.type("C")

        // Assert
        #expect(skipping.selected == 2)
        #expect(stepping.selected == 1)
    }

    @Test("given an empty cell earlier in the word when the last cell is typed then the cursor stays on the last cell")
    func staysOnLastCell() {
        // Arrange
        let state = GameState.start(puzzle: small).tapCell(1)

        // Act
        let next = typed(state, "AT")

        // Assert
        #expect(next.selected == 2)
        #expect(next.currentWord?.label == "1 Across")
    }

    @Test("given a completed word when its last letter is typed then the cursor moves to the next clue's first empty cell")
    func movesToNextClue() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries[6] = "B"

        // Act
        let next = typed(state, "CAT")

        // Assert
        #expect(next.currentWord?.label == "3 Across")
        #expect(next.selected == 7)
    }

    @Test("given the last clue completed when typing ends then the next clue wraps to Across")
    func nextClueWraps() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries = Array("C..A#.BOW")
        state = state.tapCell(2).toggleDirection()

        // Act
        let next = typed(state, "TO")

        // Assert
        #expect(next.selected == 1)
        #expect(next.currentWord?.label == "1 Across")
    }

    @Test("given a full grid when the last letter is typed then the puzzle is solved and the cursor stays")
    func solvesInPlace() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.entries = Array("CA.A#OBOW")
        state = state.tapCell(2)

        // Act
        let next = state.type("T")

        // Assert
        #expect(next.isSolved)
        #expect(next.selected == 2)
        #expect(next.backspace() == next)
    }

    @Test("given digits and punctuation when typed then they are ignored")
    func ignoresOtherKeys() {
        // Arrange
        let state = GameState.start(puzzle: small)

        // Assert
        #expect(state.type("4") == state)
        #expect(state.type("-") == state)
        #expect(state.type(" ") == state)
    }

    @Test("given a selected cell when it is tapped again then the direction toggles, unless it is in one word only")
    func tapToggles() {
        // Arrange
        let state = GameState.start(puzzle: small)

        // Act
        let toggled = state.tapCell(0)
        let single = toggled.tapCell(1)
        let singleAgain = single.tapCell(1)

        // Assert
        #expect(toggled.isAcross == false)
        #expect(single.isAcross)
        #expect(singleAgain.isAcross)
        #expect(state.tapCell(4) == state)
    }

    @Test("given an arrow across the current direction when pressed then it switches direction before moving")
    func arrowSwitchesFirst() {
        // Arrange
        let state = GameState.start(puzzle: small)

        // Act
        let switched = state.arrow(.down)
        let moved = switched.arrow(.down)
        let skipped = moved.tapCell(1).arrow(.down)

        // Assert
        #expect(switched.selected == 0)
        #expect(switched.isAcross == false)
        #expect(moved.selected == 3)
        #expect(skipped.selected == 7)
    }

    @Test("given the clue buttons when pressed then they move through clues and wrap")
    func clueSteps() {
        // Arrange
        let state = GameState.start(puzzle: small)

        // Act
        let previous = state.previousClue()
        let next = state.nextClue()
        let around = next.nextClue().nextClue().nextClue()

        // Assert
        #expect(previous.currentWord?.label == "2 Down")
        #expect(previous.selected == 2)
        #expect(next.currentWord?.label == "3 Across")
        #expect(around.currentWord?.label == "1 Across")
    }

    @Test("given a clue with a filled first cell when it is selected then the cursor lands on its first empty cell")
    func selectWordLandsOnEmpty() {
        // Arrange
        let state = typed(GameState.start(puzzle: small), "C")

        // Act
        let next = state.selectWord(2)

        // Assert
        #expect(next.selected == 3)
        #expect(next.isAcross == false)
    }

    @Test("given typed letters when undone and redone then the grid follows")
    func undoRedo() {
        // Arrange
        let state = typed(GameState.start(puzzle: small), "CA")

        // Act
        let undone = state.undo()
        let redone = undone.redo()

        // Assert
        #expect(undone.entries[1] == emptyMark)
        #expect(undone.selected == 1)
        #expect(redone.entries == state.entries)
    }

    @Test("given show mistakes when a wrong letter is typed then it is shown and counted")
    func mistakes() {
        // Arrange
        var state = GameState.start(puzzle: small)
        state.showMistakes = true

        // Act
        let next = state.type("X")

        // Assert
        #expect(next.shownWrongCells == [0])
        #expect(next.mistakes == 1)
    }

    @Test("given reveal letter and word when used then the cells take the solution and hints count")
    func reveals() {
        // Arrange
        let state = GameState.start(puzzle: small)

        // Act
        let letter = state.revealLetter()
        let word = state.revealWord()
        let all = state.revealSolution()

        // Assert
        #expect(letter.entries[0] == "C")
        #expect(letter.hints == 1)
        #expect(Array(word.entries[0..<3]) == ["C", "A", "T"])
        #expect(word.hints == 1)
        #expect(all.isSolved)
    }

    @Test("given changes and entries when encoded then they decode to the same values")
    func codecs() {
        // Arrange
        let state = typed(GameState.start(puzzle: small), "CAT").backspace()

        // Act
        let changes = ChangeCodec.decode(ChangeCodec.encode(state.changes))
        let entries = EntriesCodec.decode(EntriesCodec.encode(state.entries), puzzle: small)

        // Assert
        #expect(ChangeCodec.encode(state.changes) == "0.C,1.A,2.T,2T.")
        #expect(changes == state.changes)
        #expect(entries == state.entries)
        #expect(EntriesCodec.decode("CAT", puzzle: small) == nil)
        #expect(EntriesCodec.decode("CATAAOBOW", puzzle: small) == nil)
    }
}
