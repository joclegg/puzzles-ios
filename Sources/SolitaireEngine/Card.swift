public enum Suit: Int, CaseIterable, Sendable {
    case clubs
    case diamonds
    case hearts
    case spades

    public var symbol: Character {
        switch self {
        case .clubs:
            "♣"
        case .diamonds:
            "♦"
        case .hearts:
            "♥"
        case .spades:
            "♠"
        }
    }

    public var code: Character {
        switch self {
        case .clubs:
            "C"
        case .diamonds:
            "D"
        case .hearts:
            "H"
        case .spades:
            "S"
        }
    }

    public var isRed: Bool {
        self == .diamonds || self == .hearts
    }
}

public struct Card: Hashable, Sendable {
    public static let ace = 1
    public static let jack = 11
    public static let queen = 12
    public static let king = 13
    public static let deck: [Card] = Suit.allCases.flatMap { suit in
        (ace...king).map { Card(rank: $0, suit: suit) }
    }

    private static let rankCodes = Array("A23456789TJQK")

    public let rank: Int
    public let suit: Suit

    public init(rank: Int, suit: Suit) {
        precondition(rank >= Card.ace && rank <= Card.king, "Rank \(rank) is not between \(Card.ace) and \(Card.king)")
        self.rank = rank
        self.suit = suit
    }

    public var rankLabel: String {
        switch rank {
        case Card.ace:
            "A"
        case Card.jack:
            "J"
        case Card.queen:
            "Q"
        case Card.king:
            "K"
        default:
            String(rank)
        }
    }

    public var code: String {
        String([Card.rankCodes[rank - 1], suit.code])
    }

    public func stacksOnTableau(_ below: Card, order: BuildOrder = .down) -> Bool {
        rank + order.step == below.rank && suit.isRed != below.suit.isRed
    }

    public static func parse(_ code: String) -> Card {
        let letters = Array(code)
        precondition(letters.count == 2, "Card code '\(code)' must be two characters")
        let rank = (rankCodes.firstIndex(of: letters[0]) ?? -1) + 1
        guard let suit = Suit.allCases.first(where: { $0.code == letters[1] }) else {
            preconditionFailure("Card code '\(code)' has no such suit")
        }
        return Card(rank: rank, suit: suit)
    }
}
