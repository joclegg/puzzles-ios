public let SlideOutBoardSize = 6
public let SlideOutExitRow = 2

public enum SlideOutDecodeError: Error, Equatable, Sendable {
    case malformed(String)
}

public struct SlideOutBlock: Hashable, Sendable {
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
                return row * SlideOutBoardSize + col + step
            }
            return (row + step) * SlideOutBoardSize + col
        }
    }

    public var position: Int {
        horizontal ? col : row
    }

    public func movedTo(_ position: Int) -> SlideOutBlock {
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

    public static func decode(_ code: String) throws -> SlideOutBlock {
        let letters = Array(code)
        guard letters.count >= 4 else {
            throw SlideOutDecodeError.malformed(code)
        }
        return SlideOutBlock(
            row: try digit(letters[0], in: code),
            col: try digit(letters[1], in: code),
            length: try digit(letters[2], in: code),
            horizontal: letters[3] == "H"
        )
    }

    private static func digit(_ letter: Character, in code: String) throws -> Int {
        guard letter.isASCII, let value = letter.wholeNumberValue else {
            throw SlideOutDecodeError.malformed(code)
        }
        return value
    }
}

public struct SlideOutMove: Hashable, Sendable {
    public var block: Int
    public var position: Int

    public init(block: Int, position: Int) {
        self.block = block
        self.position = position
    }
}

public struct SlideOutBoard: Hashable, Sendable {
    public var blocks: [SlideOutBlock]

    public init(blocks: [SlideOutBlock]) {
        self.blocks = blocks
    }

    public var target: SlideOutBlock {
        blocks[0]
    }

    public var isSolved: Bool {
        target.col + target.length == SlideOutBoardSize
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
            (0...(SlideOutBoardSize - block.length)).contains(position)
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

    public func move(_ index: Int, to position: Int) -> SlideOutBoard {
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

    public static func decode(_ text: String) throws -> SlideOutBoard {
        SlideOutBoard(
            blocks: try text.split(separator: ",", omittingEmptySubsequences: false).map {
                try SlideOutBlock.decode(String($0))
            }
        )
    }
}
