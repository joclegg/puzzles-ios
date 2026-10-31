import PuzzlesCore

public enum DrawMode: CaseIterable, Sendable {
    case drawOne
    case drawThree

    public var cards: Int {
        switch self {
        case .drawOne:
            1
        case .drawThree:
            3
        }
    }
}

public enum BuildOrder: CaseIterable, Sendable {
    case down
    case up

    public var step: Int {
        switch self {
        case .down:
            1
        case .up:
            -1
        }
    }

    public var columnStarter: Int {
        switch self {
        case .down:
            Card.king
        case .up:
            Card.ace
        }
    }

    public var foundationStarter: Int {
        switch self {
        case .down:
            Card.ace
        case .up:
            Card.king
        }
    }

    public func foundationRank(placed: Int) -> Int {
        foundationStarter + step * placed
    }
}

public enum Pile: Hashable, Sendable {
    case waste
    case foundation(Int)
    case tableau(Int)
}

public struct Column: Hashable, Sendable {
    public let cards: [Card]
    public let faceUpFrom: Int

    public init(cards: [Card]) {
        self.init(cards: cards, faceUpFrom: max(cards.count - 1, 0))
    }

    public init(cards: [Card], faceUpFrom: Int) {
        self.cards = cards
        self.faceUpFrom = faceUpFrom
    }

    public var faceUp: [Card] {
        Array(cards.dropFirst(faceUpFrom))
    }

    public func isFaceUp(_ index: Int) -> Bool {
        index >= faceUpFrom
    }

    public func withoutTop(_ count: Int) -> Column {
        let remaining = Array(cards.dropLast(count))
        return Column(cards: remaining, faceUpFrom: min(faceUpFrom, max(remaining.count - 1, 0)))
    }

    public func plus(_ moved: [Card]) -> Column {
        Column(cards: cards + moved, faceUpFrom: min(faceUpFrom, cards.count))
    }
}

public struct Board: Hashable, Sendable {
    public static let columnCount = 7
    public static let foundationCount = 4

    public var tableau: [Column]
    public var stock: [Card]
    public var waste: [Card]
    public var foundations: [[Card]]

    public init(
        tableau: [Column],
        stock: [Card],
        waste: [Card] = [],
        foundations: [[Card]] = Array(repeating: [], count: Board.foundationCount)
    ) {
        self.tableau = tableau
        self.stock = stock
        self.waste = waste
        self.foundations = foundations
    }

    public var isWon: Bool {
        foundations.allSatisfy { $0.count == Card.king }
    }

    public var cardCount: Int {
        tableau.reduce(0) { $0 + $1.cards.count } + stock.count + waste.count + foundations.reduce(0) { $0 + $1.count }
    }

    public func cardsIn(_ pile: Pile) -> [Card] {
        switch pile {
        case .waste:
            waste
        case .foundation(let index):
            foundations[index]
        case .tableau(let index):
            tableau[index].cards
        }
    }

    public func draw(_ drawMode: DrawMode) -> Board {
        var next = self
        if stock.isEmpty {
            next.stock = waste.reversed()
            next.waste = []
        } else {
            let drawn = Array(stock.suffix(drawMode.cards).reversed())
            next.stock = Array(stock.dropLast(drawn.count))
            next.waste = waste + drawn
        }
        return next
    }

    public func canDraw() -> Bool {
        !stock.isEmpty || !waste.isEmpty
    }

    public func canPickUp(_ pile: Pile, count: Int, order: BuildOrder = .down) -> Bool {
        let cards = cardsIn(pile)
        switch pile {
        case .waste, .foundation:
            return count == 1 && !cards.isEmpty
        case .tableau(let index):
            guard count >= 1 && count <= cards.count - tableau[index].faceUpFrom else {
                return false
            }
            let run = cards.suffix(count)
            return zip(run, run.dropFirst()).allSatisfy { below, above in
                above.stacksOnTableau(below, order: order)
            }
        }
    }

    public func canMove(from: Pile, count: Int, to: Pile, order: BuildOrder = .down) -> Bool {
        if from == to || !canPickUp(from, count: count, order: order) {
            return false
        }
        let cards = cardsIn(from)
        let lead = cards[cards.count - count]
        switch to {
        case .waste:
            return false
        case .foundation(let index):
            return count == 1 && lead.suit.rawValue == index
                && lead.rank == order.foundationRank(placed: foundations[index].count)
        case .tableau(let index):
            guard let target = tableau[index].cards.last else {
                return lead.rank == order.columnStarter
            }
            return lead.stacksOnTableau(target, order: order)
        }
    }

    public func move(from: Pile, count: Int, to: Pile) -> Board {
        let moving = Array(cardsIn(from).suffix(count))
        return remove(from, count: count).add(to, cards: moving)
    }

    public static func deal(seed: Int64) -> Board {
        var random = XorWowRandom(seed: seed)
        return deal(deck: Card.deck.shuffled(using: &random))
    }

    public static func deal(deck: [Card]) -> Board {
        precondition(deck.count == Card.deck.count && Set(deck) == Set(Card.deck), "A deal needs every card exactly once")
        var next = 0
        var tableau: [Column] = []
        for size in 1...columnCount {
            tableau.append(Column(cards: Array(deck[next..<(next + size)])))
            next += size
        }
        return Board(tableau: tableau, stock: Array(deck.dropFirst(next)))
    }

    private func remove(_ pile: Pile, count: Int) -> Board {
        var next = self
        switch pile {
        case .waste:
            next.waste.removeLast(min(count, waste.count))
        case .foundation(let index):
            next.foundations[index].removeLast(min(count, foundations[index].count))
        case .tableau(let index):
            next.tableau[index] = tableau[index].withoutTop(count)
        }
        return next
    }

    private func add(_ pile: Pile, cards: [Card]) -> Board {
        var next = self
        switch pile {
        case .waste:
            next.waste += cards
        case .foundation(let index):
            next.foundations[index] += cards
        case .tableau(let index):
            next.tableau[index] = tableau[index].plus(cards)
        }
        return next
    }
}
