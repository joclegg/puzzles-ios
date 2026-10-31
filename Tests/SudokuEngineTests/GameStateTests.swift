import Testing

@testable import SudokuEngine

private let emptyCellAnswer4 = Grid.standard.cellAt(row: 0, col: 2)
private let emptyCellAnswer6 = Grid.standard.cellAt(row: 0, col: 3)
private let given5 = Grid.standard.cellAt(row: 0, col: 0)
private let game = GameState(puzzle: easyPuzzle)

private let noteStyles: [(HighlightStyle, Highlight, Int?)] = [
    (.cell, .noteMatch, nil),
    (.number, .peer, 5),
    (.off, .peer, nil),
]

struct GameStateTests {
    @Test("given a selected empty cell when a digit is tapped in cell-first then it is placed")
    func cellFirstPlaces() {
        // Arrange
        let selected = game.tapCell(emptyCellAnswer4)

        // Act
        let next = selected.tapDigit(4)

        // Assert
        #expect(next.values[emptyCellAnswer4] == 4)
    }

    @Test(
        "given a given cell when a digit is entered or erased then it does not change",
        arguments: [InputMode.cellFirst, .digitFirst]
    )
    func givenUnchanged(mode: InputMode) {
        // Arrange
        let playing = game.withInputMode(mode)

        // Act
        let next =
            mode == .cellFirst
            ? playing.tapCell(given5).tapDigit(9).erase()
            : playing.tapDigit(9).tapCell(given5).erase()

        // Assert
        #expect(next.values[given5] == 5)
    }

    @Test("given an active digit in digit-first when several cells are tapped then each gets the digit")
    func digitFirstFillsEach() {
        // Arrange
        let active = game.withInputMode(.digitFirst).tapDigit(4)

        // Act
        let next = active.tapCell(emptyCellAnswer4).tapCell(emptyCellAnswer6)

        // Assert
        #expect([next.values[emptyCellAnswer4], next.values[emptyCellAnswer6]] == [4, 4])
    }

    @Test("given a cell holding the active digit when it is tapped in digit-first then it clears")
    func digitFirstClears() {
        // Arrange
        let placed = game.withInputMode(.digitFirst).tapDigit(4).tapCell(emptyCellAnswer4)

        // Act
        let next = placed.tapCell(emptyCellAnswer4)

        // Assert
        #expect(next.values[emptyCellAnswer4] == 0)
    }

    @Test(
        "given an active digit when any cell is tapped then the active digit stays selected",
        arguments: [
            Grid.standard.cellAt(row: 0, col: 0),
            Grid.standard.cellAt(row: 0, col: 2),
            Grid.standard.cellAt(row: 0, col: 3),
        ]
    )
    func activeDigitStays(cell: Int) {
        // Arrange
        let active =
            game
            .withInputMode(.digitFirst)
            .tapDigit(9)
            .tapCell(emptyCellAnswer4)
            .tapDigit(4)

        // Act
        let next = active.tapCell(cell)

        // Assert
        #expect(next.activeDigit == 4)
    }

    @Test("given an active digit when the same digit is tapped again then it is deselected")
    func sameDigitDeselects() {
        // Arrange
        let active = game.withInputMode(.digitFirst).tapDigit(4)

        // Act
        let next = active.tapDigit(4)

        // Assert
        #expect(next.activeDigit == nil)
    }

    @Test(
        "given a mistake checking level when a digit is entered then it is placed, flagged or refused",
        arguments: [
            (MistakeCheck.showWrong, 9, 9, 1, true),
            (MistakeCheck.showWrong, 4, 4, 0, false),
            (MistakeCheck.off, 9, 9, 0, false),
            (MistakeCheck.blockClashes, 1, 1, 0, false),
            (MistakeCheck.blockClashes, 5, 0, 1, false),
        ]
    )
    func mistakeLevels(level: MistakeCheck, digit: Int, expectedValue: Int, expectedMistakes: Int, expectedWrong: Bool) {
        // Arrange
        let selected = GameState(puzzle: easyPuzzle, mistakeCheck: level).tapCell(emptyCellAnswer4)

        // Act
        let next = selected.tapDigit(digit)

        // Assert
        #expect(next.values[emptyCellAnswer4] == expectedValue)
        #expect(next.mistakes == expectedMistakes)
        #expect(next.isWrong(emptyCellAnswer4) == expectedWrong)
    }

    @Test("given block clashes when a digit already in the row is entered then the clashing cells are reported")
    func clashesReported() {
        // Arrange
        let selected = GameState(puzzle: easyPuzzle, mistakeCheck: .blockClashes).tapCell(emptyCellAnswer4)

        // Act
        let next = selected.tapDigit(5)

        // Assert
        #expect(next.rejected == Rejection(cell: emptyCellAnswer4, clashes: [given5]))
    }

    @Test("given a refused entry when the next cell is tapped then the refusal is cleared")
    func refusalCleared() {
        // Arrange
        let refused = GameState(puzzle: easyPuzzle, mistakeCheck: .blockClashes).tapCell(emptyCellAnswer4).tapDigit(5)

        // Act
        let next = refused.tapCell(emptyCellAnswer6)

        // Assert
        #expect(next.rejected == nil)
    }

    @Test("given show wrong on a puzzle without a known answer when checking is worked out then it falls back to blocking clashes")
    func fallsBackToBlocking() {
        // Arrange
        let unverified = GameState(puzzle: unverifiedPuzzle, mistakeCheck: .showWrong)

        // Act
        let level = unverified.effectiveMistakeCheck

        // Assert
        #expect(level == .blockClashes)
    }

    @Test(
        "given a peer's pencil mark when the digit is placed then it is cleared only with auto clean-up on",
        arguments: [(true, 0), (false, 16)]
    )
    func autoCleanUp(autoRemoveNotes: Bool, expectedNotes: Int) {
        // Arrange
        let withNote = GameState(puzzle: easyPuzzle, options: PlayOptions(autoRemoveNotes: autoRemoveNotes))
            .toggleNotesMode()
            .tapCell(emptyCellAnswer6)
            .tapDigit(4)
            .toggleNotesMode()

        // Act
        let next = withNote.tapCell(emptyCellAnswer4).tapDigit(4)

        // Assert
        #expect(next.notes[emptyCellAnswer6] == expectedNotes)
    }

    @Test("given a selected cell when mark is used twice then it is marked and then unmarked")
    func markToggles() {
        // Arrange
        let selected = game.tapCell(emptyCellAnswer4)

        // Act
        let marked = selected.mark()

        // Assert
        #expect(marked.marked == [emptyCellAnswer4])
        #expect(marked.mark().marked.isEmpty)
    }

    @Test("given number first with mark on when cells are tapped then they are marked and nothing is entered")
    func numberFirstMarks() {
        // Arrange
        let marking = GameState(puzzle: easyPuzzle, inputMode: .digitFirst).mark()

        // Act
        let next = marking.tapCell(emptyCellAnswer4).tapCell(emptyCellAnswer6)

        // Assert
        #expect(next.marked == [emptyCellAnswer4, emptyCellAnswer6])
        #expect(next.values == marking.values)
    }

    @Test("given an undone move when redo is used then the move is back, and the notes it cleared are cleared again")
    func redoRestores() {
        // Arrange
        let placed = game.tapCell(emptyCellAnswer4).tapDigit(4)

        // Act
        let redone = placed.undo().redo()

        // Assert
        #expect(redone.values == placed.values)
        #expect(redone.notes == placed.notes)
        #expect(redone.undoStack.count == placed.undoStack.count)
    }

    @Test("given an undone move when a new move is made then there is nothing to redo")
    func newMoveClearsRedo() {
        // Arrange
        let undone = game.tapCell(emptyCellAnswer4).tapDigit(4).undo()

        // Act
        let next = undone.tapCell(emptyCellAnswer6).tapDigit(6)

        // Assert
        #expect(next.redo() == next)
    }

    @Test("given a placed digit when undo is used then the cell is empty again")
    func undoEmpties() {
        // Arrange
        let placed = game.tapCell(emptyCellAnswer4).tapDigit(4)

        // Act
        let next = placed.undo()

        // Assert
        #expect(next.values[emptyCellAnswer4] == 0)
    }

    @Test("given 500 moves when undo is used 500 times then the board is back to the start")
    func unlimitedUndo() {
        // Arrange
        var state = game.toggleNotesMode().tapCell(emptyCellAnswer4)
        for move in 0..<500 {
            state = state.tapDigit(move % 9 + 1)
        }

        // Act
        for _ in 0..<500 {
            state = state.undo()
        }

        // Assert
        #expect(state.notes == game.notes)
        #expect(state.undoStack.isEmpty)
    }

    @Test("given a placement that cleared a pencil mark when undo is used then the pencil mark is back")
    func undoRestoresNote() {
        // Arrange
        let placed =
            game
            .toggleNotesMode()
            .tapCell(emptyCellAnswer6)
            .tapDigit(4)
            .toggleNotesMode()
            .tapCell(emptyCellAnswer4)
            .tapDigit(4)

        // Act
        let next = placed.undo()

        // Assert
        #expect(next.notes[emptyCellAnswer6] == digitBit(4))
    }

    @Test("given a move history when it is encoded and decoded then it is unchanged")
    func moveCodecRoundTrip() throws {
        // Arrange
        let played =
            game
            .tapCell(emptyCellAnswer4)
            .tapDigit(4)
            .toggleNotesMode()
            .tapCell(emptyCellAnswer6)
            .tapDigit(6)

        // Act
        let decoded = try MoveCodec.decode(MoveCodec.encode(played.undoStack))

        // Assert
        #expect(decoded == played.undoStack)
    }

    @Test(
        "given the top-left given is selected when highlights are worked out then each cell gets the expected one",
        arguments: [
            (PlayOptions(), Grid.standard.cellAt(row: 0, col: 0), Highlight.selected),
            (PlayOptions(), Grid.standard.cellAt(row: 0, col: 1), Highlight.peer),
            (PlayOptions(), Grid.standard.cellAt(row: 1, col: 5), Highlight.sameDigit),
            (PlayOptions(), Grid.standard.cellAt(row: 4, col: 3), Highlight.none),
            (PlayOptions(highlightHouses: false), Grid.standard.cellAt(row: 0, col: 1), Highlight.none),
            (PlayOptions(sameNumberStyle: .off), Grid.standard.cellAt(row: 1, col: 5), Highlight.none),
            (PlayOptions(sameNumberStyle: .number), Grid.standard.cellAt(row: 1, col: 5), Highlight.none),
        ]
    )
    func highlights(options: PlayOptions, cell: Int, expected: Highlight) {
        // Arrange
        let selected = GameState(puzzle: easyPuzzle, options: options).tapCell(given5)

        // Act
        let highlight = selected.highlight(cell)

        // Assert
        #expect(highlight == expected)
    }

    @Test("given an active digit in digit-first when highlights are worked out then cells with it are highlighted")
    func activeDigitHighlights() {
        // Arrange
        let active = game.withInputMode(.digitFirst).tapDigit(8)

        // Act
        let highlight = active.highlight(Grid.standard.cellAt(row: 2, col: 2))

        // Assert
        #expect(highlight == .sameDigit)
    }

    @Test("given one empty cell left when its answer is entered then the game is complete")
    func completes() throws {
        // Arrange
        var values = try #require(easyPuzzle.solution)
        values[emptyCellAnswer4] = 0
        let nearlyDone = GameState(puzzle: easyPuzzle, values: values)

        // Act
        let next = nearlyDone.tapCell(emptyCellAnswer4).tapDigit(4)

        // Assert
        #expect(next.isComplete)
    }

    @Test(
        "given a two-cell cage when both cells are filled then a wrong total is flagged",
        arguments: [(3, true), (4, false)]
    )
    func cageTotalFlagged(firstDigit: Int, expectedWrong: Bool) {
        // Arrange
        let cage = Cage(cells: [emptyCellAnswer4, emptyCellAnswer6], sum: 10)
        let puzzle = Puzzle(givens: easyPuzzle.givens, solution: easyPuzzle.solution, cages: [cage])
        let killer = GameState(puzzle: puzzle)

        // Act
        let next =
            killer
            .tapCell(emptyCellAnswer4)
            .tapDigit(firstDigit)
            .tapCell(emptyCellAnswer6)
            .tapDigit(6)

        // Assert
        #expect(next.isCageWrong(cage) == expectedWrong)
    }

    @Test(
        "given the board when a digit is counted then givens and entries both count",
        arguments: [(false, 2), (true, 3)]
    )
    func digitCounts(placeAnother4: Bool, expectedCount: Int) {
        // Arrange
        let board = placeAnother4 ? game.tapCell(emptyCellAnswer4).tapDigit(4) : game

        // Act
        let count = board.digitCount(4)

        // Assert
        #expect(count == expectedCount)
    }

    @Test("given number-first when erase is tapped then it stays selected and the active digit is dropped")
    func eraseStaysSelected() {
        // Arrange
        let active = game.withInputMode(.digitFirst).tapDigit(4)

        // Act
        let next = active.erase()

        // Assert
        #expect(next.eraserActive)
        #expect(next.activeDigit == nil)
    }

    @Test("given the eraser in number-first when filled cells are tapped then each is cleared and givens are kept")
    func eraserClears() {
        // Arrange
        let filled =
            game
            .withInputMode(.digitFirst)
            .tapDigit(4)
            .tapCell(emptyCellAnswer4)
            .tapDigit(6)
            .tapCell(emptyCellAnswer6)
        let erasing = filled.erase()

        // Act
        let next = erasing.tapCell(emptyCellAnswer4).tapCell(emptyCellAnswer6).tapCell(given5)

        // Assert
        #expect([next.values[emptyCellAnswer4], next.values[emptyCellAnswer6], next.values[given5]] == [0, 0, 5])
    }

    @Test(
        "given the eraser in number-first when erase or a digit is tapped then erasing stops",
        arguments: [("erase", false), ("digit", false)]
    )
    func erasingStops(action: String, expected: Bool) {
        // Arrange
        let erasing = game.withInputMode(.digitFirst).erase()

        // Act
        let next = action == "erase" ? erasing.erase() : erasing.tapDigit(3)

        // Assert
        #expect(next.eraserActive == expected)
    }

    @Test("given cell-first and a selected filled cell when erase is tapped then that cell is cleared")
    func cellFirstErase() {
        // Arrange
        let filled = game.tapCell(emptyCellAnswer4).tapDigit(4)

        // Act
        let next = filled.erase()

        // Assert
        #expect(next.values[emptyCellAnswer4] == 0)
        #expect(!next.eraserActive)
    }

    @Test(
        "given a placement when the next action happens then the last placed cell is tracked",
        arguments: [("place", true), ("undo", false), ("clear", false)]
    )
    func lastPlacedTracked(action: String, expectTracked: Bool) {
        // Arrange
        let placed = game.tapCell(emptyCellAnswer4).tapDigit(4)

        // Act
        let next: GameState
        switch action {
        case "undo":
            next = placed.undo()
        case "clear":
            next = placed.tapDigit(4)
        default:
            next = placed
        }

        // Assert
        #expect(next.lastPlaced == (expectTracked ? emptyCellAnswer4 : nil))
    }

    @Test(
        "given a just filled cell when highlights are worked out then the selection shows only if last placed highlighting is on",
        arguments: [(true, Highlight.selected, Highlight.peer), (false, Highlight.sameDigit, Highlight.none)]
    )
    func justFilledHighlight(highlightLastPlaced: Bool, expectedCell: Highlight, expectedPeer: Highlight) {
        // Arrange
        let placed = GameState(puzzle: easyPuzzle, options: PlayOptions(highlightLastPlaced: highlightLastPlaced))
            .tapCell(emptyCellAnswer4)
            .tapDigit(4)

        // Act
        let cell = placed.highlight(emptyCellAnswer4)
        let peer = placed.highlight(Grid.standard.cellAt(row: 8, col: 2))

        // Assert
        #expect(cell == expectedCell)
        #expect(peer == expectedPeer)
    }

    @Test("given just-filled highlighting off when a pencil mark is added then the cell is not highlighted as selected")
    func pencilMarkNotSelected() {
        // Arrange
        let noting = GameState(puzzle: easyPuzzle, options: PlayOptions(highlightLastPlaced: false))
            .toggleNotesMode()
            .tapCell(emptyCellAnswer4)

        // Act
        let next = noting.tapDigit(2)

        // Assert
        #expect(next.highlight(emptyCellAnswer4) == Highlight.none)
    }

    @Test(
        "given a pencil mark matching the selected number when highlights are worked out then the style decides how it shows",
        arguments: noteStyles
    )
    func noteStyle(style: HighlightStyle, expectedCell: Highlight, expectedNoteDigit: Int?) {
        // Arrange
        let noted = GameState(puzzle: easyPuzzle, options: PlayOptions(notesStyle: style))
            .toggleNotesMode()
            .tapCell(emptyCellAnswer6)
            .tapDigit(5)
            .toggleNotesMode()

        // Act
        let selected = noted.tapCell(given5)

        // Assert
        #expect(selected.highlight(emptyCellAnswer6) == expectedCell)
        #expect(selected.noteHighlightDigit == expectedNoteDigit)
    }

    @Test(
        "given the same number elsewhere when the style is number then the digit itself is highlighted",
        arguments: [(HighlightStyle.cell, false), (HighlightStyle.number, true), (HighlightStyle.off, false)]
    )
    func numberStyle(style: HighlightStyle, expected: Bool) {
        // Arrange
        let options = PlayOptions(sameNumberStyle: style)

        // Act
        let selected = GameState(puzzle: easyPuzzle, options: options).tapCell(given5)

        // Assert
        #expect(selected.isNumberHighlighted(Grid.standard.cellAt(row: 1, col: 5)) == expected)
    }

    @Test("given a game with entries and notes when it is restarted then only the givens are left")
    func restartClears() {
        // Arrange
        let played =
            game
            .tapCell(emptyCellAnswer4)
            .tapDigit(9)
            .toggleNotesMode()
            .tapCell(emptyCellAnswer6)
            .tapDigit(2)

        // Act
        let restarted = played.restart()

        // Assert
        #expect(restarted.values == easyPuzzle.givens)
        #expect(restarted.notes == Grid.standard.emptyValues())
        #expect(restarted.undoStack.isEmpty)
        #expect(restarted.mistakes == 0)
    }

    @Test("given a puzzle with a known answer when the solution is revealed then the board is the answer")
    func revealsSolution() {
        // Act
        let revealed = game.revealSolution()

        // Assert
        #expect(revealed.values == easyPuzzle.solution)
        #expect(revealed.isComplete)
    }

    @Test("given a puzzle without a known answer when the solution is revealed then nothing changes")
    func revealWithoutAnswer() {
        // Arrange
        let unverified = GameState(puzzle: unverifiedPuzzle)

        // Act
        let revealed = unverified.revealSolution()

        // Assert
        #expect(revealed == unverified)
    }
}
