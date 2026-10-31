import PuzzlesCore

public struct Puzzle: Sendable, Equatable {
    public let givens: Grid
    public let solution: Grid

    public init(givens: Grid, solution: Grid) {
        self.givens = givens
        self.solution = solution
    }

    public var size: Int {
        givens.size
    }

    public func isGiven(_ cell: Int) -> Bool {
        givens.tiles[cell] != .empty
    }

    public func encode() -> String {
        "\(size);\(givens.encode());\(solution.encode())"
    }

    public static func decode(_ text: String) -> Puzzle? {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 3,
            let size = Int(parts[0]),
            let givens = Grid.parse(size: size, text: String(parts[1])),
            let solution = Grid.parse(size: size, text: String(parts[2]))
        else {
            return nil
        }
        return Puzzle(givens: givens, solution: solution)
    }
}

public enum Generator {
    private static let dailySeedSpread: Int64 = 7_919

    public static func dailySeed(date: CalendarDay, size: Int) -> Int64 {
        Int64(date.daysSinceEpoch) * dailySeedSpread + Int64(size)
    }

    public static func daily(date: CalendarDay, size: Int) -> Puzzle {
        generate(size: size, seed: dailySeed(date: date, size: size))
    }

    public static func generate(size: Int, seed: Int64) -> Puzzle {
        var random = XorWowRandom(seed: seed)
        guard let solution = fill(Grid.empty(size: size), cell: 0, random: &random) else {
            preconditionFailure("No \(size) x \(size) grid could be filled")
        }
        var givens = solution
        for cell in Array(solution.tiles.indices).shuffled(using: &random) {
            let without = givens.with(cell: cell, tile: .empty)
            if Solver.solveLogically(without) == solution {
                givens = without
            }
        }
        return Puzzle(givens: givens, solution: solution)
    }

    private static func fill(_ grid: Grid, cell: Int, random: inout XorWowRandom) -> Grid? {
        if cell == grid.tiles.count {
            return grid
        }
        let options = [Tile.red, Tile.blue].shuffled(using: &random)
        for tile in options {
            let next = grid.with(cell: cell, tile: tile)
            if fits(next, cell: cell), let filled = fill(next, cell: cell + 1, random: &random) {
                return filled
            }
        }
        return nil
    }

    private static func fits(_ grid: Grid, cell: Int) -> Bool {
        let row = Line(isRow: true, index: cell / grid.size)
        let column = Line(isRow: false, index: cell % grid.size)
        return [row, column].allSatisfy { line in
            let tiles = grid.tilesOf(line)
            let noThree = stride(from: 0, through: grid.size - Grid.run, by: 1).allSatisfy { start in
                let run = tiles[start..<(start + Grid.run)]
                return run.first == .empty || !run.allSatisfy { $0 == run.first }
            }
            let balanced = [Tile.red, Tile.blue].allSatisfy { tile in
                tiles.count { $0 == tile } <= grid.size / 2
            }
            let unique = tiles.contains(.empty) || !grid.hasTwin(of: line, tiles: tiles)
            return noThree && balanced && unique
        }
    }
}
