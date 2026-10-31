public enum DecodeError: Error, Equatable, Sendable {
    case malformed(String)
}

public struct Cell: Hashable, Sendable {
    public var row: Int
    public var col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct Placement: Hashable, Sendable {
    public var word: String
    public var row: Int
    public var col: Int
    public var across: Bool

    public init(word: String, row: Int, col: Int, across: Bool) {
        self.word = word
        self.row = row
        self.col = col
        self.across = across
    }

    public var cells: [Cell] {
        (0..<word.count).map { step in
            if across {
                return Cell(row: row, col: col + step)
            }
            return Cell(row: row + step, col: col)
        }
    }

    public func encode() -> String {
        "\(word)@\(row),\(col),\(across ? "A" : "D")"
    }

    public static func decode(_ text: String) throws -> Placement {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            throw DecodeError.malformed(text)
        }
        let position = parts[1].split(separator: ",", omittingEmptySubsequences: false)
        guard position.count >= 3, let row = Int(position[0]), let col = Int(position[1]) else {
            throw DecodeError.malformed(text)
        }
        return Placement(word: String(parts[0]), row: row, col: col, across: position[2] == "A")
    }
}

public struct Crossword: Hashable, Sendable {
    public var placements: [Placement]

    public init(placements: [Placement]) {
        self.placements = placements
    }

    public var letters: [Cell: Character] {
        var result: [Cell: Character] = [:]
        for placement in placements {
            for (cell, letter) in zip(placement.cells, placement.word) {
                result[cell] = letter
            }
        }
        return result
    }

    public var rows: Int {
        (letters.keys.map(\.row).max() ?? -1) + 1
    }

    public var cols: Int {
        (letters.keys.map(\.col).max() ?? -1) + 1
    }

    public var words: [String] {
        var seen = Set<String>()
        return placements.map(\.word).filter { seen.insert($0).inserted }
    }

    public func canPlace(_ placement: Placement) -> Bool {
        let existing = letters
        let cells = placement.cells
        var crossings = 0
        for (cell, letter) in zip(cells, placement.word) {
            if let there = existing[cell] {
                if there != letter
                    || placements.contains(where: { $0.across == placement.across && $0.cells.contains(cell) })
                {
                    return false
                }
                crossings += 1
            } else {
                let sides =
                    placement.across
                    ? [Cell(row: cell.row - 1, col: cell.col), Cell(row: cell.row + 1, col: cell.col)]
                    : [Cell(row: cell.row, col: cell.col - 1), Cell(row: cell.row, col: cell.col + 1)]
                if sides.contains(where: { existing[$0] != nil }) {
                    return false
                }
            }
        }
        guard let end = cells.last else {
            return false
        }
        let before =
            placement.across
            ? Cell(row: placement.row, col: placement.col - 1)
            : Cell(row: placement.row - 1, col: placement.col)
        let after =
            placement.across
            ? Cell(row: end.row, col: end.col + 1)
            : Cell(row: end.row + 1, col: end.col)
        return crossings > 0
            && existing[before] == nil
            && existing[after] == nil
            && !placements.contains { $0.word == placement.word }
    }

    public func encode() -> String {
        placements.map { $0.encode() }.joined(separator: "|")
    }

    public static func decode(_ text: String) throws -> Crossword {
        Crossword(
            placements: try text.split(separator: "|", omittingEmptySubsequences: false).map {
                try Placement.decode(String($0))
            }
        )
    }
}

public struct Puzzle: Hashable, Sendable {
    public var letters: String
    public var crossword: Crossword

    public init(letters: String, crossword: Crossword) {
        self.letters = letters
        self.crossword = crossword
    }

    public func encode() -> String {
        "\(letters);\(crossword.encode())"
    }

    public static func decode(_ text: String) throws -> Puzzle {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 2 else {
            throw DecodeError.malformed(text)
        }
        return Puzzle(letters: String(parts[0]), crossword: try Crossword.decode(String(parts[1])))
    }
}
