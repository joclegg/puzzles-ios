public enum Tile: Character, Sendable, CaseIterable {
    case empty = "."
    case red = "R"
    case blue = "B"

    public var code: Character {
        rawValue
    }

    public var other: Tile {
        switch self {
        case .red:
            .blue
        case .blue:
            .red
        case .empty:
            .empty
        }
    }

    public var next: Tile {
        switch self {
        case .empty:
            .red
        case .red:
            .blue
        case .blue:
            .empty
        }
    }
}

public let sizes = [4, 6, 8, 10, 12]

public struct Line: Sendable, Hashable {
    public let isRow: Bool
    public let index: Int

    public init(isRow: Bool, index: Int) {
        self.isRow = isRow
        self.index = index
    }
}

public struct Grid: Sendable, Hashable {
    public static let run = 3

    public let size: Int
    public let tiles: [Tile]

    public init(size: Int, tiles: [Tile]) {
        precondition(Grid.isValid(size: size, count: tiles.count), "A grid needs an even size and size x size tiles")
        self.size = size
        self.tiles = tiles
    }

    public static func empty(size: Int) -> Grid {
        Grid(size: size, tiles: [Tile](repeating: .empty, count: size * size))
    }

    public static func parse(size: Int, text: String) -> Grid? {
        var tiles: [Tile] = []
        for character in text where !character.isWhitespace {
            guard let tile = Tile(rawValue: character) else {
                return nil
            }
            tiles.append(tile)
        }
        guard isValid(size: size, count: tiles.count) else {
            return nil
        }
        return Grid(size: size, tiles: tiles)
    }

    private static func isValid(size: Int, count: Int) -> Bool {
        size % 2 == 0 && count == size * size
    }

    public var lines: [Line] {
        (0..<size).flatMap { [Line(isRow: true, index: $0), Line(isRow: false, index: $0)] }
    }

    public var isFull: Bool {
        !tiles.contains(.empty)
    }

    public func cellsOf(_ line: Line) -> [Int] {
        (0..<size).map { position in
            line.isRow ? line.index * size + position : position * size + line.index
        }
    }

    public func tilesOf(_ line: Line) -> [Tile] {
        cellsOf(line).map { tiles[$0] }
    }

    public func with(cell: Int, tile: Tile) -> Grid {
        var updated = tiles
        updated[cell] = tile
        return Grid(size: size, tiles: updated)
    }

    public func brokenCells() -> Set<Int> {
        var broken = Set<Int>()
        for line in lines {
            let cells = cellsOf(line)
            let lineTiles = tilesOf(line)
            for start in stride(from: 0, through: size - Grid.run, by: 1) {
                let run = lineTiles[start..<(start + Grid.run)]
                if run.first != .empty && run.allSatisfy({ $0 == run.first }) {
                    broken.formUnion(cells[start..<(start + Grid.run)])
                }
            }
            for tile in [Tile.red, Tile.blue] where lineTiles.count(where: { $0 == tile }) > size / 2 {
                broken.formUnion(cells.filter { tiles[$0] == tile })
            }
            if !lineTiles.contains(.empty) && hasTwin(of: line, tiles: lineTiles) {
                broken.formUnion(cells)
            }
        }
        return broken
    }

    public func encode() -> String {
        String(tiles.map(\.code))
    }

    func hasTwin(of line: Line, tiles lineTiles: [Tile]) -> Bool {
        lines.contains { $0 != line && $0.isRow == line.isRow && tilesOf($0) == lineTiles }
    }
}
