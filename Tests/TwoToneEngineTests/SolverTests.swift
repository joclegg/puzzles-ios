import Testing

@testable import TwoToneEngine

struct SolverTests {
    @Test(
        "given a row with one forced tile when the next deduction is found then it names the tile and the rule",
        arguments: [
            ("RR.. ........ ....", 2, Tile.blue, Reason.pair),
            (".BB. ........ ....", 0, Tile.red, Reason.pair),
            ("R.R. ........ ....", 1, Tile.blue, Reason.gap),
            ("RB.R ........ ....", 2, Tile.blue, Reason.balance),
        ]
    )
    func forced(text: String, cell: Int, tile: Tile, reason: Reason) {
        // Arrange
        let grid = Grid.parse(size: 4, text: text)!

        // Act
        let deduction = Solver.next(grid)

        // Assert
        #expect(deduction?.cells.first == cell)
        #expect(deduction?.tile == tile)
        #expect(deduction?.reason == reason)
    }

    @Test("given a row that would copy a full row when the next deduction is found then it picks the other way round")
    func uniqueRow() {
        // Arrange
        let grid = Grid.parse(size: 6, text: "RBBRBR ...... ...... ...... ...... R.BRB.")!

        // Act
        let deduction = Solver.next(grid)

        // Assert
        #expect(deduction?.cells == [31])
        #expect(deduction?.tile == .red)
        #expect(deduction?.reason == .unique)
        #expect(deduction?.twin == Line(isRow: true, index: 0))
    }

    @Test("given an empty grid when the next deduction is looked for then there is none")
    func emptyGrid() {
        // Act
        let deduction = Solver.next(Grid.empty(size: 4))

        // Assert
        #expect(deduction == nil)
    }
}
