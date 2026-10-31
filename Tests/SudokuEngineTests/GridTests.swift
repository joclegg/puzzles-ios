import Testing

@testable import SudokuEngine

struct GridTests {
    @Test(
        "given a grid and a cell when its box is worked out then it matches the grid's box shape",
        arguments: [
            (Grid.standard, 0, 0, 0),
            (Grid.standard, 4, 4, 4),
            (Grid.standard, 8, 8, 8),
            (Grid.fast, 0, 0, 0),
            (Grid.fast, 0, 3, 1),
            (Grid.fast, 2, 0, 2),
            (Grid.fast, 5, 5, 5),
        ]
    )
    func boxShape(grid: Grid, row: Int, col: Int, expectedBox: Int) {
        // Act
        let box = grid.boxOf(grid.cellAt(row: row, col: col))

        // Assert
        #expect(box == expectedBox)
    }

    @Test(
        "given a grid when its houses and peers are built then every house has size cells and every cell the right peers",
        arguments: [(Grid.standard, 20), (Grid.fast, 12)]
    )
    func housesAndPeers(grid: Grid, expectedPeers: Int) {
        // Act
        let houseSizes = Set(grid.houses.map(\.count))
        let peerCounts = Set(grid.peers.map(\.count))

        // Assert
        #expect(houseSizes == [grid.size])
        #expect(peerCounts == [expectedPeers])
    }

    @Test(
        "given a cell when its neighbours are listed then only cells sharing an edge are included",
        arguments: [
            (Grid.standard, 0, Set([1, 9])),
            (Grid.standard, 40, Set([31, 39, 41, 49])),
            (Grid.standard, 80, Set([71, 79])),
            (Grid.fast, 0, Set([1, 6])),
            (Grid.fast, 35, Set([29, 34])),
        ]
    )
    func neighbours(grid: Grid, cell: Int, expected: Set<Int>) {
        // Act
        let neighbours = Set(grid.neighbours(cell))

        // Assert
        #expect(neighbours == expected)
    }
}
