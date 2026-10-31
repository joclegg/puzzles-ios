public enum BoardCodec {
    private static let sections: Character = ";"
    private static let piles: Character = "|"
    private static let faceUp: Character = "/"

    public static func encode(_ board: Board) -> String {
        let tableau = board.tableau.map { column in
            cards(Array(column.cards.prefix(column.faceUpFrom))) + String(faceUp) + cards(column.faceUp)
        }
        return [
            tableau.joined(separator: String(piles)),
            cards(board.stock),
            cards(board.waste),
            board.foundations.map { cards($0) }.joined(separator: String(piles)),
        ].joined(separator: String(sections))
    }

    public static func decode(_ text: String) -> Board {
        let parts = text.split(separator: sections, omittingEmptySubsequences: false)
        precondition(parts.count >= 4, "Board text '\(text)' needs four sections")
        let tableau = parts[0].split(separator: piles, omittingEmptySubsequences: false).map { column in
            let sides = column.split(separator: faceUp, omittingEmptySubsequences: false)
            precondition(sides.count >= 2, "Column text '\(column)' needs a face up marker")
            let faceDown = cards(sides[0])
            return Column(cards: faceDown + cards(sides[1]), faceUpFrom: faceDown.count)
        }
        return Board(
            tableau: tableau,
            stock: cards(parts[1]),
            waste: cards(parts[2]),
            foundations: parts[3].split(separator: piles, omittingEmptySubsequences: false).map { cards($0) }
        )
    }

    private static func cards(_ cards: [Card]) -> String {
        cards.map(\.code).joined()
    }

    private static func cards(_ text: Substring) -> [Card] {
        let letters = Array(text)
        return stride(from: 0, to: letters.count, by: 2).map { start in
            Card.parse(String(letters[start..<min(start + 2, letters.count)]))
        }
    }
}

public enum MoveCodec {
    private static let draw = "D"

    public static func encode(_ moves: [Move]) -> String {
        moves.map { move in
            switch move {
            case .draw:
                draw
            case .transfer(let from, let count, let to):
                "\(pile(from))\(count)\(pile(to))"
            }
        }.joined(separator: ",")
    }

    public static func decode(_ text: String) -> [Move] {
        text.split(separator: ",").map { move in
            if move == draw {
                return .draw
            }
            let letters = Array(move)
            guard let count = Int(String(letters.dropFirst(2).dropLast(2))) else {
                preconditionFailure("Move text '\(move)' has no count")
            }
            return .transfer(
                from: pile(Array(letters.prefix(2))),
                count: count,
                to: pile(Array(letters.suffix(2)))
            )
        }
    }

    private static func pile(_ pile: Pile) -> String {
        switch pile {
        case .waste:
            "W0"
        case .foundation(let index):
            "F\(index)"
        case .tableau(let index):
            "T\(index)"
        }
    }

    private static func pile(_ code: [Character]) -> Pile {
        guard code.count == 2, let index = code[1].wholeNumberValue else {
            preconditionFailure("Pile code '\(String(code))' is not valid")
        }
        switch code[0] {
        case "W":
            return .waste
        case "F":
            return .foundation(index)
        default:
            return .tableau(index)
        }
    }
}
