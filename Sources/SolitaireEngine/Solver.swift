public enum Verdict: CaseIterable, Sendable {
    case winnable
    case unwinnable
    case unknown
}

public enum Solver {
    public static let defaultBudget = 200_000
    private static let dealBudget = 20_000
    private static let separator = UInt8(ascii: "|")
    private static let cardBytes = Card.deck.map { Array($0.code.utf8) }
    private static let numberBytes = (0...Card.deck.count).map { Array(String($0).utf8) }

    public static func solve(
        _ start: Board,
        drawMode: DrawMode,
        order: BuildOrder,
        budget: Int = defaultBudget,
        quickOnly: Bool = false,
        shouldStop: () -> Bool = { false }
    ) -> Verdict {
        let quick = search(start, drawMode: drawMode, order: order, budget: budget, thorough: false, shouldStop: shouldStop)
        if quick == .winnable {
            return .winnable
        }
        if quickOnly {
            return .unknown
        }
        return search(start, drawMode: drawMode, order: order, budget: budget, thorough: true, shouldStop: shouldStop)
    }

    public static func winnableDeal(seed: Int64, drawMode: DrawMode, order: BuildOrder) -> Board {
        var next = seed
        while true {
            let board = Board.deal(seed: next)
            if solve(board, drawMode: drawMode, order: order, budget: dealBudget, quickOnly: true) == .winnable {
                return board
            }
            next &+= 1
        }
    }

    private static func search(
        _ start: Board,
        drawMode: DrawMode,
        order: BuildOrder,
        budget: Int,
        thorough: Bool,
        shouldStop: () -> Bool
    ) -> Verdict {
        var seen = Set<[UInt8]>()
        var stack = [settle(start, drawMode: drawMode, order: order)]
        var explored = 0
        while let board = stack.popLast() {
            if board.isWon {
                return .winnable
            }
            if !seen.insert(key(board)).inserted {
                continue
            }
            explored += 1
            if explored > budget || shouldStop() {
                return .unknown
            }
            for next in moves(board, drawMode: drawMode, order: order, thorough: thorough).reversed() {
                stack.append(settle(next, drawMode: drawMode, order: order))
            }
        }
        return .unwinnable
    }

    private static func moves(_ board: Board, drawMode: DrawMode, order: BuildOrder, thorough: Bool) -> [Board] {
        var foundation: [Board] = []
        var revealing: [Board] = []
        var other: [Board] = []
        let foundations = (0..<Board.foundationCount).map { Pile.foundation($0) }
        let columns = board.tableau.indices.map { Pile.tableau($0) }
        for from in [Pile.waste] + columns {
            for to in foundations where board.canMove(from: from, count: 1, to: to, order: order) {
                foundation.append(board.move(from: from, count: 1, to: to))
            }
        }
        for (index, column) in board.tableau.enumerated() {
            let from = Pile.tableau(index)
            let faceUpCount = column.cards.count - column.faceUpFrom
            for count in stride(from: 1, through: faceUpCount, by: 1) {
                let reveals = count == faceUpCount && column.faceUpFrom > 0
                let wholeColumn = count == column.cards.count
                for (target, to) in columns.enumerated() {
                    if to == from || !board.canMove(from: from, count: count, to: to, order: order) {
                        continue
                    }
                    if wholeColumn && board.tableau[target].cards.isEmpty {
                        continue
                    }
                    let moved = board.move(from: from, count: count, to: to)
                    if reveals || wholeColumn {
                        revealing.append(moved)
                    } else if thorough || freesFoundationCard(moved, column: from, order: order) {
                        other.append(moved)
                    }
                }
            }
        }
        for to in columns {
            if board.canMove(from: .waste, count: 1, to: to, order: order) {
                other.append(board.move(from: .waste, count: 1, to: to))
            }
            for from in thorough ? foundations : [] where board.canMove(from: from, count: 1, to: to, order: order) {
                other.append(board.move(from: from, count: 1, to: to))
            }
        }
        if board.canDraw() {
            other.append(board.draw(drawMode))
        }
        return foundation + revealing + other
    }

    private static func freesFoundationCard(_ board: Board, column: Pile, order: BuildOrder) -> Bool {
        (0..<Board.foundationCount).contains { board.canMove(from: column, count: 1, to: .foundation($0), order: order) }
    }

    private static func settle(_ start: Board, drawMode: DrawMode, order: BuildOrder) -> Board {
        var board = start
        while let safe = safeFoundationMove(board, drawMode: drawMode, order: order) {
            board = safe
        }
        return board
    }

    private static func safeFoundationMove(_ board: Board, drawMode: DrawMode, order: BuildOrder) -> Board? {
        let columns = board.tableau.indices.map { Pile.tableau($0) }
        let tops = drawMode == .drawOne ? [Pile.waste] + columns : columns
        for from in tops {
            guard let card = board.cardsIn(from).last else {
                continue
            }
            let to = Pile.foundation(card.suit.rawValue)
            if !board.canMove(from: from, count: 1, to: to, order: order) {
                continue
            }
            let placedBefore = board.foundations[card.suit.rawValue].count
            let oppositeCaughtUp = Suit.allCases.allSatisfy { suit in
                suit.isRed == card.suit.isRed || board.foundations[suit.rawValue].count >= placedBefore
            }
            if placedBefore <= 1 || oppositeCaughtUp {
                return board.move(from: from, count: 1, to: to)
            }
        }
        return nil
    }

    private static func key(_ board: Board) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(128)
        for column in board.tableau {
            bytes += numberBytes[column.faceUpFrom]
            append(column.cards, to: &bytes)
            bytes.append(separator)
        }
        append(board.stock, to: &bytes)
        bytes.append(separator)
        append(board.waste, to: &bytes)
        bytes.append(separator)
        for foundation in board.foundations {
            bytes += numberBytes[foundation.count]
        }
        return bytes
    }

    private static func append(_ cards: [Card], to bytes: inout [UInt8]) {
        for card in cards {
            bytes += cardBytes[card.suit.rawValue * Card.king + card.rank - 1]
        }
    }
}
