public enum Reason: Sendable, Equatable, CaseIterable {
    case pair
    case gap
    case balance
    case unique
}

public struct Deduction: Sendable, Equatable {
    public let cells: [Int]
    public let tile: Tile
    public let reason: Reason
    public let line: Line
    public let twin: Line?

    public init(cells: [Int], tile: Tile, reason: Reason, line: Line, twin: Line? = nil) {
        self.cells = cells
        self.tile = tile
        self.reason = reason
        self.line = line
        self.twin = twin
    }
}

public enum Solver {
    public static func next(_ grid: Grid) -> Deduction? {
        let lines = grid.lines
        for rule in [pairOrGap, balance, unique] {
            for line in lines {
                if let deduction = rule(grid, line) {
                    return deduction
                }
            }
        }
        return nil
    }

    public static func solveLogically(_ grid: Grid) -> Grid? {
        var current = grid
        while !current.isFull {
            guard let deduction = next(current) else {
                return nil
            }
            for cell in deduction.cells {
                current = current.with(cell: cell, tile: deduction.tile)
            }
            if !current.brokenCells().isEmpty {
                return nil
            }
        }
        return current
    }

    private static func pairOrGap(_ grid: Grid, _ line: Line) -> Deduction? {
        let cells = grid.cellsOf(line)
        let tiles = grid.tilesOf(line)
        for start in stride(from: 0, through: grid.size - Grid.run, by: 1) {
            let a = tiles[start]
            let b = tiles[start + 1]
            let c = tiles[start + 2]
            if a == .empty && b != .empty && b == c {
                return Deduction(cells: [cells[start]], tile: b.other, reason: .pair, line: line)
            }
            if c == .empty && a != .empty && a == b {
                return Deduction(cells: [cells[start + 2]], tile: a.other, reason: .pair, line: line)
            }
            if b == .empty && a != .empty && a == c {
                return Deduction(cells: [cells[start + 1]], tile: a.other, reason: .gap, line: line)
            }
        }
        return nil
    }

    private static func balance(_ grid: Grid, _ line: Line) -> Deduction? {
        let tiles = grid.tilesOf(line)
        guard tiles.contains(.empty) else {
            return nil
        }
        let full = [Tile.red, Tile.blue].first { tile in
            tiles.count { $0 == tile } == grid.size / 2
        }
        guard let full else {
            return nil
        }
        let empties = grid.cellsOf(line).filter { grid.tiles[$0] == .empty }
        return Deduction(cells: empties, tile: full.other, reason: .balance, line: line)
    }

    private static func unique(_ grid: Grid, _ line: Line) -> Deduction? {
        let cells = grid.cellsOf(line)
        let tiles = grid.tilesOf(line)
        let empties = cells.filter { grid.tiles[$0] == .empty }
        guard empties.count == 2 else {
            return nil
        }
        let missingRed = grid.size / 2 - tiles.count { $0 == .red }
        guard missingRed == 1 else {
            return nil
        }
        let twins = grid.lines.filter { candidate in
            candidate != line && candidate.isRow == line.isRow && !grid.tilesOf(candidate).contains(.empty)
        }
        for twin in twins {
            let twinTiles = grid.tilesOf(twin)
            let matchesFilled = tiles.indices.allSatisfy { tiles[$0] == .empty || tiles[$0] == twinTiles[$0] }
            if matchesFilled, let first = cells.firstIndex(of: empties[0]) {
                return Deduction(
                    cells: [empties[0]],
                    tile: twinTiles[first].other,
                    reason: .unique,
                    line: line,
                    twin: twin
                )
            }
        }
        return nil
    }
}
