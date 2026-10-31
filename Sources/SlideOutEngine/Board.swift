public let boardSize = 6
public let exitRow = 2

public enum DecodeError: Error, Equatable, Sendable {
    case malformed(String)
}

public struct Block: Hashable, Sendable {
    public var row: Int
    public var col: Int
    public var length: Int
    public var horizontal: Bool

    public init(row: Int, col: Int, length: Int, horizontal: Bool) {
        self.row = row
        self.col = col
        self.length = length
        self.horizontal = horizontal
    }

    public var cells: [Int] {
        (0..<length).map { step in
            if horizontal {
                return row * boardSize + col + step
            }
            return (row + step) * boardSize + col
        }
    }

    public var position: Int {
        horizontal ? col : row
    }

    public func movedTo(_ position: Int) -> Block {
        var next = self
        if horizontal {
            next.col = position
        } else {
            next.row = position
        }
        return next
    }

    public func encode() -> String {
        "\(row)\(col)\(length)\(horizontal ? "H" : "V")"
    }

    public static func decode(_ code: String) throws -> Block {
        let letters = Array(code)
        guard letters.count >= 4 else {
            throw DecodeError.malformed(code)
        }
        return Block(
            row: try digit(letters[0], in: code),
            col: try digit(letters[1], in: code),
            length: try digit(letters[2], in: code),
            horizontal: letters[3] == "H"
        )
    }

    private static func digit(_ letter: Character, in code: String) throws -> Int {
        guard letter.isASCII, let value = letter.wholeNumberValue else {
            throw DecodeError.malformed(code)
        }
        return value
    }
}

public struct Move: Hashable, Sendable {
    public var block: Int
    public var position: Int

    public init(block: Int, position: Int) {
        self.block = block
        self.position = position
    }
}

public struct Board: Hashable, Sendable {
    public var blocks: [Block]

    public init(blocks: [Block]) {
        self.blocks = blocks
    }

    public var target: Block {
        blocks[0]
    }

    public var isSolved: Bool {
        target.col + target.length == boardSize
    }

    public func occupied(except: Int? = nil) -> Set<Int> {
        var cells = Set<Int>()
        for (index, block) in blocks.enumerated() where index != except {
            cells.formUnion(block.cells)
        }
        return cells
    }

    public func range(_ index: Int) -> ClosedRange<Int> {
        let block = blocks[index]
        let taken = occupied(except: index)
        func free(_ position: Int) -> Bool {
            (0...(boardSize - block.length)).contains(position)
                && !block.movedTo(position).cells.contains(where: taken.contains)
        }
        var low = block.position
        while free(low - 1) {
            low -= 1
        }
        var high = block.position
        while free(high + 1) {
            high += 1
        }
        return low...high
    }

    public func move(_ index: Int, to position: Int) -> Board {
        var next = self
        next.blocks[index] = blocks[index].movedTo(position)
        return next
    }

    public func encode() -> String {
        blocks.map { $0.encode() }.joined(separator: ",")
    }

    public func identity() -> String {
        ([blocks[0].encode()] + blocks.dropFirst().map { $0.encode() }.sorted()).joined(separator: ",")
    }

    public static func decode(_ text: String) throws -> Board {
        Board(
            blocks: try text.split(separator: ",", omittingEmptySubsequences: false).map {
                try Block.decode(String($0))
            }
        )
    }
}
