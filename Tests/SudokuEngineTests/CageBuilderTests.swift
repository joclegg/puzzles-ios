import Testing

@testable import SudokuEngine

private let topLeft = Grid.standard.cellAt(row: 0, col: 0)
private let rightOfTopLeft = Grid.standard.cellAt(row: 0, col: 1)
private let belowTopLeft = Grid.standard.cellAt(row: 1, col: 0)
private let farAway = Grid.standard.cellAt(row: 5, col: 5)
private let pair = CageBuilder().tapCell(topLeft).tapCell(rightOfTopLeft)

private let problems: [(CageBuilder, CageProblem?)] = [
    (CageBuilder(selection: [topLeft, rightOfTopLeft], sumInput: "3"), nil),
    (CageBuilder(selection: [topLeft, rightOfTopLeft], sumInput: "2"), .impossibleSum),
    (CageBuilder(selection: [topLeft, rightOfTopLeft], sumInput: "18"), .impossibleSum),
    (CageBuilder(selection: [topLeft, farAway], sumInput: "9"), .notConnected),
    (CageBuilder(selection: [topLeft, rightOfTopLeft]), .empty),
]

struct CageBuilderTests {
    @Test("given a selection when neighbouring cells are tapped then the selection grows")
    func selectionGrows() {
        // Arrange
        let started = CageBuilder().tapCell(topLeft)

        // Act
        let grown = started.tapCell(rightOfTopLeft).tapCell(belowTopLeft)

        // Assert
        #expect(grown.selection == [topLeft, rightOfTopLeft, belowTopLeft])
    }

    @Test("given a selection when a cell that doesn't touch it is tapped then a new selection starts")
    func newSelectionStarts() {
        // Act
        let next = pair.tapCell(farAway)

        // Assert
        #expect(next.selection == [farAway])
    }

    @Test("given two selected cells when 17 is typed and confirmed then a cage is saved")
    func cageSaved() {
        // Act
        let built = pair.typeDigit(1).typeDigit(7).confirm()

        // Assert
        #expect(built.cages == [Cage(cells: [topLeft, rightOfTopLeft], sum: 17)])
        #expect(built.selection.isEmpty)
    }

    @Test(
        "given digits typed for a sum when the sum is read then it keeps at most two digits",
        arguments: [([1], "1"), ([1, 7], "17"), ([1, 2, 4], "4")]
    )
    func typedSums(typed: [Int], expected: String) {
        // Act
        let sum = typed.reduce(CageBuilder()) { $0.typeDigit($1) }.sumInput

        // Assert
        #expect(sum == expected)
    }

    @Test("given a selection and sum when it is checked then impossible cages are refused", arguments: problems)
    func refusesImpossible(builder: CageBuilder, expected: CageProblem?) {
        // Act
        let problem = builder.problem()

        // Assert
        #expect(problem == expected)
    }

    @Test("given a refused sum when new digits are typed then the sum starts again")
    func refusedSumRestarts() {
        // Arrange
        let refused = pair.typeDigit(1).confirm()

        // Act
        let retyped = refused.typeDigit(1).typeDigit(7)

        // Assert
        #expect(retyped.sumInput == "17")
    }

    @Test("given a saved cage when it is tapped and a new sum typed then the cage is updated")
    func cageUpdated() {
        // Arrange
        let editing = pair.typeDigit(9).confirm().tapCell(rightOfTopLeft)

        // Act
        let updated = editing.typeDigit(1).typeDigit(1).confirm()

        // Assert
        #expect(updated.cages == [Cage(cells: [topLeft, rightOfTopLeft], sum: 11)])
    }

    @Test("given a saved cage when it is tapped and deleted then it is gone")
    func cageDeleted() {
        // Arrange
        let editing = pair.typeDigit(9).confirm().tapCell(rightOfTopLeft)

        // Act
        let deleted = editing.deleteSelection()

        // Assert
        #expect(deleted.cages.isEmpty)
    }
}
