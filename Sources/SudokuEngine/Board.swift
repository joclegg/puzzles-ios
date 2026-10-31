public let noCage = -1

private let maxDigit = 9

public func digitBit(_ digit: Int) -> Int {
    1 << digit
}

public func singleDigit(_ mask: Int) -> Int {
    mask.trailingZeroBitCount
}

public func digitsOf(_ mask: Int) -> [Int] {
    (1...maxDigit).filter { mask & digitBit($0) != 0 }
}

func orderedUnique(_ items: [Int]) -> [Int] {
    var seen = Set<Int>()
    return items.filter { seen.insert($0).inserted }
}

public struct Grid: Sendable, Equatable {
    public static let standard = Grid(size: 9, boxRows: 3, boxCols: 3)
    public static let fast = Grid(size: 6, boxRows: 2, boxCols: 3)

    public let size: Int
    public let boxRows: Int
    public let boxCols: Int
    public let cells: Int
    public let digits: ClosedRange<Int>
    public let allDigits: Int
    public let rows: [[Int]]
    public let cols: [[Int]]
    public let boxes: [[Int]]
    public let houses: [[Int]]
    public let peers: [[Int]]
    private let boxesPerRow: Int

    private init(size: Int, boxRows: Int, boxCols: Int) {
        let cells = size * size
        let boxesPerRow = size / boxCols
        let boxOf = { (cell: Int) in (cell / size / boxRows) * boxesPerRow + (cell % size) / boxCols }
        let rows = (0..<size).map { row in (0..<size).map { col in row * size + col } }
        let cols = (0..<size).map { col in (0..<size).map { row in row * size + col } }
        let boxes = (0..<size).map { box in (0..<cells).filter { boxOf($0) == box } }
        self.size = size
        self.boxRows = boxRows
        self.boxCols = boxCols
        self.cells = cells
        self.boxesPerRow = boxesPerRow
        digits = 1...size
        allDigits = (1...size).reduce(0) { $0 | digitBit($1) }
        self.rows = rows
        self.cols = cols
        self.boxes = boxes
        houses = rows + cols + boxes
        peers = (0..<cells).map { cell in
            (0..<cells).filter { other in
                other != cell
                    && (other / size == cell / size || other % size == cell % size || boxOf(other) == boxOf(cell))
            }
        }
    }

    public static func forCellCount(_ cells: Int) -> Grid {
        if cells == standard.cells {
            return standard
        }
        if cells == fast.cells {
            return fast
        }
        preconditionFailure("No grid has \(cells) cells")
    }

    public static func == (lhs: Grid, rhs: Grid) -> Bool {
        lhs.size == rhs.size
    }

    public func rowOf(_ cell: Int) -> Int {
        cell / size
    }

    public func colOf(_ cell: Int) -> Int {
        cell % size
    }

    public func boxOf(_ cell: Int) -> Int {
        (rowOf(cell) / boxRows) * boxesPerRow + colOf(cell) / boxCols
    }

    public func cellAt(row: Int, col: Int) -> Int {
        row * size + col
    }

    public func sharesHouse(_ a: Int, _ b: Int) -> Bool {
        rowOf(a) == rowOf(b) || colOf(a) == colOf(b) || boxOf(a) == boxOf(b)
    }

    public func neighbours(_ cell: Int) -> [Int] {
        let last = size - 1
        let row = rowOf(cell)
        let col = colOf(cell)
        var result: [Int] = []
        if row > 0 {
            result.append(cell - size)
        }
        if row < last {
            result.append(cell + size)
        }
        if col > 0 {
            result.append(cell - 1)
        }
        if col < last {
            result.append(cell + 1)
        }
        return result
    }

    public func emptyValues() -> [Int] {
        [Int](repeating: 0, count: cells)
    }
}

public struct Cage: Sendable, Equatable {
    public let cells: [Int]
    public let sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells
        self.sum = sum
    }
}

public struct Puzzle: Sendable, Equatable {
    public let givens: [Int]
    public let solution: [Int]?
    public let cages: [Cage]
    public let cageIndexByCell: [Int]

    public init(givens: [Int], solution: [Int]?, cages: [Cage] = []) {
        precondition(solution == nil || solution?.count == givens.count)
        self.givens = givens
        self.solution = solution
        self.cages = cages
        var index = [Int](repeating: noCage, count: givens.count)
        for (cage, item) in cages.enumerated() {
            for cell in item.cells {
                index[cell] = cage
            }
        }
        cageIndexByCell = index
    }

    public var grid: Grid {
        Grid.forCellCount(givens.count)
    }

    public var isKiller: Bool {
        !cages.isEmpty
    }

    public var givenCount: Int {
        givens.count { $0 != 0 }
    }
}

public enum CodecError: Error, Sendable, Equatable {
    case malformed
}

func parts(_ text: some StringProtocol, separator: Character) -> [String] {
    String(text).split(separator: separator, omittingEmptySubsequences: false).map(String.init)
}

func integer(_ text: String) throws -> Int {
    guard let value = Int(text) else {
        throw CodecError.malformed
    }
    return value
}

public enum PuzzleCodec {
    public static func encode(_ puzzle: Puzzle) -> String {
        let givens = joined(puzzle.givens)
        let solution = puzzle.solution.map(joined) ?? ""
        let cages = puzzle.cages.map { cage in
            "\(cage.sum):\(cage.cells.map(String.init).joined(separator: ","))"
        }
        return "\(givens)|\(solution)|\(cages.joined(separator: ";"))"
    }

    public static func decode(_ line: String) throws -> Puzzle {
        let sections = parts(trimmed(line), separator: "|")
        if sections.count > 3 {
            throw CodecError.malformed
        }
        let filled = sections + [String](repeating: "", count: 3 - sections.count)
        let givens = try digits(filled[0])
        let solution = filled[1].isEmpty ? nil : try digits(filled[1])
        if let solution, solution.count != givens.count {
            throw CodecError.malformed
        }
        let cages = try parts(filled[2], separator: ";").filter { !$0.isEmpty }.map(cage)
        if cages.contains(where: { $0.cells.contains { !givens.indices.contains($0) } }) {
            throw CodecError.malformed
        }
        return Puzzle(givens: givens, solution: solution, cages: cages)
    }

    private static func cage(_ text: String) throws -> Cage {
        let fields = parts(text, separator: ":")
        if fields.count < 2 {
            throw CodecError.malformed
        }
        let cells = try parts(fields[1], separator: ",").map(integer)
        return Cage(cells: cells, sum: try integer(fields[0]))
    }

    private static func digits(_ text: String) throws -> [Int] {
        try text.map { character in
            guard character.isASCII, let digit = character.wholeNumberValue else {
                throw CodecError.malformed
            }
            return digit
        }
    }

    private static func joined(_ digits: [Int]) -> String {
        digits.map(String.init).joined()
    }

    private static func trimmed(_ text: String) -> Substring {
        var result = Substring(text)
        while let first = result.first, first.isWhitespace {
            result.removeFirst()
        }
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }
        return result
    }
}
