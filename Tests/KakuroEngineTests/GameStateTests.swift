import Testing

@testable import KakuroEngine

struct GameStateTests {
    @Test("given a selected cell when a digit is tapped then it is placed, and tapping it again clears it")
    func tapPlacesAndClears() {
        // Arrange
        let game = GameState(puzzle: small).tapCell(4)

        // Act
        let placed = game.tapDigit(1)
        let cleared = placed.tapDigit(1)

        // Assert
        #expect(placed.values[4] == 1)
        #expect(cleared.values[4] == 0)
    }

    @Test("given notes mode when digits are tapped then they toggle as notes")
    func notesToggle() {
        // Act
        let game = GameState(puzzle: small)
            .tapCell(4)
            .toggleNotes()
            .tapDigit(1)
            .tapDigit(2)
            .tapDigit(1)

        // Assert
        #expect(game.values[4] == 0)
        #expect(Combinations.digitsOf(game.notes[4]) == [2])
    }

    @Test("given a filled cell in notes mode when a digit is tapped then the cell keeps its digit")
    func filledCellKeepsDigit() {
        // Act
        let game = GameState(puzzle: small)
            .tapCell(4)
            .tapDigit(1)
            .toggleNotes()
            .tapDigit(2)

        // Assert
        #expect(game.values[4] == 1)
        #expect(game.notes[4] == 0)
    }

    @Test("given a starting digit when a digit is tapped on it then it does not change")
    func givenUnchanged() {
        // Act
        let game = GameState(puzzle: puzzle(3, "000 012 034", givens: [4])).tapCell(4).tapDigit(9)

        // Assert
        #expect(game.values[4] == 1)
    }

    @Test("given entries when they are all undone then the grid is back to the start", arguments: [1, 3])
    func undoAll(entries: Int) {
        // Arrange
        let played = (1...entries).reduce(GameState(puzzle: small).tapCell(5)) { state, digit in state.tapDigit(digit) }

        // Act
        let undone = (1...entries).reduce(played) { state, _ in state.undo() }

        // Assert
        #expect(undone.values == [Int](repeating: 0, count: 9))
    }

    @Test("given a run with a repeated digit when broken runs are found then it is listed")
    func brokenRun() {
        // Act
        let game = GameState(puzzle: small)
            .tapCell(4)
            .tapDigit(2)
            .tapCell(5)
            .tapDigit(2)

        // Assert
        #expect(game.brokenRuns.filter(\.isAcross) == [Run(cells: [4, 5], sum: 3, isAcross: true, clueCell: 3)])
    }

    @Test("given every cell filled correctly when it is checked then the puzzle is solved")
    func solved() {
        // Act
        let game = [(4, 1), (5, 2), (7, 3), (8, 4)].reduce(GameState(puzzle: small)) { state, entry in
            state.tapCell(entry.0).tapDigit(entry.1)
        }

        // Assert
        #expect(game.isSolved)
    }

    @Test("given changes saved and replayed when the game is rebuilt then values and notes match")
    func replayMatches() throws {
        // Arrange
        let played = GameState(puzzle: small)
            .tapCell(4)
            .tapDigit(1)
            .toggleNotes()
            .tapCell(5)
            .tapDigit(2)

        // Act
        let changes = try #require(ChangeCodec.decode(ChangeCodec.encode(played.changes)))
        let replayed = GameState.replay(puzzle: small, changes: changes)

        // Assert
        #expect(replayed.values == played.values)
        #expect(replayed.notes == played.notes)
    }

    @Test("given a selected cell when its combinations are listed then each run shows the digit sets that still fit")
    func selectedCombinations() {
        // Act
        let combos = GameState(puzzle: small)
            .tapCell(5)
            .tapDigit(2)
            .tapCell(4)
            .selectedCombinations()

        // Assert
        #expect(combos.map { $0.masks.map(Combinations.digitsOf) } == [[[1, 2]], [[1, 3]]])
    }

    @Test("given number first with a digit picked when cells are tapped then the digit goes in, and tapping again clears it")
    func numberFirstPlaces() {
        // Arrange
        let game = GameState(puzzle: small, inputMode: .digitFirst).tapDigit(1)

        // Act
        let placed = game.tapCell(4)
        let cleared = placed.tapCell(4)

        // Assert
        #expect(placed.values[4] == 1)
        #expect(cleared.values[4] == 0)
    }

    @Test("given number first with erase on when a filled cell is tapped then it is cleared")
    func numberFirstErases() {
        // Arrange
        let game = GameState(puzzle: small, inputMode: .digitFirst).tapDigit(2).tapCell(5).erase()

        // Act
        let after = game.tapCell(5)

        // Assert
        #expect(after.values[5] == 0)
    }

    @Test("given block clashes when a digit already in the run is entered then it is refused and counted")
    func blockClashes() {
        // Arrange
        let game = GameState(puzzle: small, mistakeCheck: .blockClashes).tapCell(5).tapDigit(2).tapCell(4)

        // Act
        let after = game.tapDigit(2)

        // Assert
        #expect(after.values[4] == 0)
        #expect(after.rejected == 4)
        #expect(after.mistakes == 1)
    }

    @Test(
        "given a mistake check level when a wrong digit is entered then it is shown and counted only when showing wrong",
        arguments: [MistakeCheck.off, MistakeCheck.showWrong]
    )
    func mistakeLevels(level: MistakeCheck) {
        // Arrange
        let game = GameState(puzzle: small, mistakeCheck: level).tapCell(4)

        // Act
        let after = game.tapDigit(9)

        // Assert
        let showing = level == .showWrong
        #expect(after.shownWrongCells.contains(4) == showing)
        #expect((after.mistakes == 1) == showing)
    }

    @Test("given every one of a digit placed correctly when it is checked then that digit is done")
    func digitDone() {
        // Act
        let game = GameState(puzzle: small).tapCell(4).tapDigit(1)

        // Assert
        #expect(game.isDigitDone(1))
        #expect(!game.isDigitDone(2))
    }

    @Test("given pencil marks in the same runs when a digit is placed then those marks are removed, and undo puts them back")
    func autoRemoveAndUndo() {
        // Arrange
        let noted = GameState(puzzle: small)
            .toggleNotes()
            .tapCell(5)
            .tapDigit(1)
            .tapCell(7)
            .tapDigit(1)
            .tapCell(8)
            .tapDigit(1)
            .toggleNotes()

        // Act
        let placed = noted.tapCell(4).tapDigit(1)
        let undone = placed.undo()

        // Assert
        #expect([5, 7, 8].map { placed.notes[$0] } == [0, 0, 1])
        #expect(undone.notes == noted.notes)
    }

    @Test("given auto remove turned off when a digit is placed then other pencil marks stay")
    func autoRemoveOff() {
        // Arrange
        let noted = GameState(puzzle: small, autoRemoveNotes: false)
            .toggleNotes()
            .tapCell(5)
            .tapDigit(1)
            .toggleNotes()

        // Act
        let placed = noted.tapCell(4).tapDigit(1)

        // Assert
        #expect(placed.notes[5] == 1)
    }

    @Test("given changes that cleared pencil marks when they are saved and replayed then the marks match")
    func replayClearedMarks() throws {
        // Arrange
        let played = GameState(puzzle: small)
            .toggleNotes()
            .tapCell(5)
            .tapDigit(1)
            .toggleNotes()
            .tapCell(4)
            .tapDigit(1)

        // Act
        let changes = try #require(ChangeCodec.decode(ChangeCodec.encode(played.changes)))
        let replayed = GameState.replay(puzzle: small, changes: changes)

        // Assert
        #expect(replayed.notes == played.notes)
    }

    @Test("given two undone taps when redo is used twice then both are back, pencil marks included")
    func redoTwice() {
        // Arrange
        let played = GameState(puzzle: small)
            .toggleNotes()
            .tapCell(5)
            .tapDigit(1)
            .toggleNotes()
            .tapCell(4)
            .tapDigit(1)

        // Act
        let redone =
            played
            .undo()
            .undo()
            .redo()
            .redo()

        // Assert
        #expect(redone.values == played.values)
        #expect(redone.notes == played.notes)
        #expect(redone.changes == played.changes)
    }

    @Test("given an undone tap when a new digit is placed then there is nothing to redo")
    func newDigitClearsRedo() {
        // Arrange
        let undone = GameState(puzzle: small).tapCell(4).tapDigit(1).undo()

        // Act
        let next = undone.tapDigit(2)

        // Assert
        #expect(next.redo() == next)
    }

    @Test("given a selected cell when mark is used twice then it is marked and then unmarked")
    func markTwice() {
        // Arrange
        let selected = GameState(puzzle: small).tapCell(4)

        // Act
        let marked = selected.mark()

        // Assert
        #expect(marked.marked == [4])
        #expect(marked.mark().marked.isEmpty)
    }

    @Test("given number first with mark on when cells are tapped then they are marked and nothing is entered")
    func numberFirstMarks() {
        // Arrange
        let marking = GameState(puzzle: small, inputMode: .digitFirst).mark()

        // Act
        let next = marking.tapCell(4).tapCell(5)

        // Assert
        #expect(next.marked == [4, 5])
        #expect(next.values == marking.values)
    }

    @Test("given a change that cleared pencil marks when it is encoded then the text matches the synced format")
    func changeWireFormat() throws {
        // Arrange
        let text = "4,0,0,1,0,5:7;8,0,4,0,0"

        // Act
        let changes = try #require(ChangeCodec.decode(text))

        // Assert
        #expect(changes[0].clearedNotes == [5, 7])
        #expect(ChangeCodec.encode(changes) == text)
    }
}
