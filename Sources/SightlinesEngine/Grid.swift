public enum Dot: Character, Sendable, CaseIterable {
    case empty = "."
    case blue = "B"
    case red = "R"

    public var code: Character {
        rawValue
    }

    public var next: Dot {
        switch self {
        case .empty:
            .blue
        case .blue:
            .red
        case .red:
            .empty
        }
    }
}

public let sizes = Array(4...9)

public enum Direction: Sendable, CaseIterable {
    case up
    case down
    case left
    case right

    public var rowStep: Int {
        switch self {
        case .up:
            -1
        case .down:
            1
        case .left, .right:
            0
        }
    }

    public var colStep: Int {
        switch self {
        case .left:
            -1
        case .right:
            1
        case .up, .down:
            0
        }
    }
}

public struct Grid: Sendable, Hashable {
    public let size: Int
    public let dots: [Dot]

    public init(size: Int, dots: [Dot]) {
        precondition(dots.count == size * size, "A grid needs size x size dots")
        self.size = size
        self.dots = dots
    }

    public static func empty(size: Int) -> Grid {
        Grid(size: size, dots: [Dot](repeating: .empty, count: size * size))
    }

    public static func parse(size: Int, text: String) -> Grid? {
        var dots: [Dot] = []
        for character in text where !character.isWhitespace {
            guard let dot = Dot(rawValue: character) else {
                return nil
            }
            dots.append(dot)
        }
        guard dots.count == size * size else {
            return nil
        }
        return Grid(size: size, dots: dots)
    }

    public var isFull: Bool {
        !dots.contains(.empty)
    }

    public func with(cell: Int, dot: Dot) -> Grid {
        var updated = dots
        updated[cell] = dot
        return Grid(size: size, dots: updated)
    }

    public func ray(_ cell: Int, direction: Direction) -> [Int] {
        var cells: [Int] = []
        var row = cell / size + direction.rowStep
        var col = cell % size + direction.colStep
        while (0..<size).contains(row) && (0..<size).contains(col) {
            cells.append(row * size + col)
            row += direction.rowStep
            col += direction.colStep
        }
        return cells
    }

    public func seen(_ cell: Int, direction: Direction) -> Int {
        ray(cell, direction: direction).prefix { dots[$0] == .blue }.count
    }

    public func seen(_ cell: Int) -> Int {
        Direction.allCases.reduce(0) { $0 + seen(cell, direction: $1) }
    }

    public func reach(_ cell: Int, direction: Direction) -> Int {
        ray(cell, direction: direction).prefix { dots[$0] != .red }.count
    }

    public func encode() -> String {
        String(dots.map(\.code))
    }
}

public struct Puzzle: Sendable, Equatable {
    private static let radix = 36
    private static let wall: Character = "X"

    public let solution: Grid
    public let numbers: [Int: Int]
    public let walls: Set<Int>

    public init(solution: Grid, numbers: [Int: Int], walls: Set<Int>) {
        self.solution = solution
        self.numbers = numbers
        self.walls = walls
    }

    public var size: Int {
        solution.size
    }

    public var givens: Grid {
        Grid(
            size: size,
            dots: solution.dots.indices.map { cell in
                if numbers[cell] != nil {
                    return .blue
                }
                return walls.contains(cell) ? .red : .empty
            }
        )
    }

    public func isGiven(_ cell: Int) -> Bool {
        numbers[cell] != nil || walls.contains(cell)
    }

    public func brokenCells(_ grid: Grid) -> Set<Int> {
        Set(
            grid.dots.indices.filter { cell in
                let reach = Direction.allCases.reduce(0) { $0 + grid.reach(cell, direction: $1) }
                if let number = numbers[cell] {
                    return grid.seen(cell) > number || reach < number
                }
                return grid.dots[cell] == .blue && reach == 0
            }
        )
    }

    public func encode() -> String {
        let clues = solution.dots.indices.map { cell -> String in
            if let number = numbers[cell] {
                return String(number, radix: Puzzle.radix)
            }
            return walls.contains(cell) ? String(Puzzle.wall) : "."
        }
        return "\(size);\(clues.joined());\(solution.encode())"
    }

    public static func decode(_ text: String) -> Puzzle? {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 3,
            let size = Int(parts[0]),
            let solution = Grid.parse(size: size, text: String(parts[2]))
        else {
            return nil
        }
        var numbers: [Int: Int] = [:]
        var walls = Set<Int>()
        for (cell, code) in parts[1].enumerated() {
            if code == "." {
                continue
            }
            if code == wall {
                walls.insert(cell)
                continue
            }
            guard let number = Int(String(code), radix: radix) else {
                return nil
            }
            numbers[cell] = number
        }
        return Puzzle(solution: solution, numbers: numbers, walls: walls)
    }
}
