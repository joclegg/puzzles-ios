import Testing

@testable import SightlinesEngine

struct GridTests {
    @Test(
        "given a grid when a cell looks along its row and column then it sees blue dots up to the first red",
        arguments: [
            ("BBB. .... .... ....", 0, 2, 6),
            ("BBRB B... B... R...", 0, 3, 3),
            ("BRBB .... .... ....", 0, 0, 3),
            ("B... B... B... B...", 5, 1, 6),
        ]
    )
    func sight(text: String, cell: Int, seen: Int, reach: Int) {
        // Arrange
        let grid = Grid.parse(size: 4, text: text)!

        // Act
        let seenResult = grid.seen(cell)
        let reachResult = Direction.allCases.reduce(0) { $0 + grid.reach(cell, direction: $1) }

        // Assert
        #expect(seenResult == seen)
        #expect(reachResult == reach)
    }
}
