import PuzzlesCore

public enum Move: Hashable, Sendable {
    case draw
    case transfer(from: Pile, count: Int, to: Pile)
}

public struct Selection: Hashable, Sendable {
    public let pile: Pile
    public let count: Int

    public init(pile: Pile, count: Int) {
        self.pile = pile
        self.count = count
    }
}

extension Board {
    fileprivate func applying(_ move: Move, drawMode: DrawMode) -> Board {
        switch move {
        case .draw:
            draw(drawMode)
        case .transfer(let from, let count, let to):
            self.move(from: from, count: count, to: to)
        }
    }

    fileprivate func applying(_ moves: some Sequence<Move>, drawMode: DrawMode) -> Board {
        moves.reduce(self) { $0.applying($1, drawMode: drawMode) }
    }
}

public struct GameState: Sendable, Equatable {
    public let start: Board
    public let drawMode: DrawMode
    public let moves: [Move]
    public let board: Board
    public var selection: Selection?
    public var oneTapMove: Bool
    public var order: BuildOrder

    public init(
        start: Board,
        drawMode: DrawMode,
        moves: [Move] = [],
        selection: Selection? = nil,
        oneTapMove: Bool = true,
        order: BuildOrder = .down
    ) {
        self.start = start
        self.drawMode = drawMode
        self.moves = moves
        self.board = start.applying(moves, drawMode: drawMode)
        self.selection = selection
        self.oneTapMove = oneTapMove
        self.order = order
    }

    public var isWon: Bool {
        board.isWon
    }

    public var moveCount: Int {
        moves.count
    }

    public var canAutoFinish: Bool {
        !isWon && board.stock.isEmpty && board.waste.isEmpty && board.tableau.allSatisfy { $0.faceUpFrom == 0 }
    }

    public var cycledStock: Bool {
        let draws = moves.reversed().prefix { $0 == .draw }.count
        var current = start.applying(moves.dropLast(draws), drawMode: drawMode)
        let cards = current.stock.count + current.waste.count
        if cards == 0 {
            return true
        }
        if drawMode.cards == 1 {
            return draws >= cards + 1
        }
        var drawsSinceTurnOver = -1
        for _ in 0..<draws {
            if drawsSinceTurnOver >= 0 {
                drawsSinceTurnOver += 1
            } else if current.stock.isEmpty {
                drawsSinceTurnOver = 0
            }
            current = current.draw(drawMode)
        }
        return drawsSinceTurnOver >= (cards + drawMode.cards - 1) / drawMode.cards
    }

    public func autoFinishMoves() -> [Move] {
        if !canAutoFinish {
            return []
        }
        var finishing: [Move] = []
        var current = board
        while !current.isWon {
            var next: (from: Pile, to: Pile)?
            for index in current.tableau.indices {
                guard let card = current.tableau[index].cards.last else {
                    continue
                }
                let from = Pile.tableau(index)
                let to = Pile.foundation(card.suit.rawValue)
                if current.canMove(from: from, count: 1, to: to, order: order) {
                    next = (from, to)
                    break
                }
            }
            guard let next else {
                return []
            }
            finishing.append(.transfer(from: next.from, count: 1, to: next.to))
            current = current.move(from: next.from, count: 1, to: next.to)
        }
        return finishing
    }

    public func autoFinish() -> GameState {
        if canAutoFinish {
            return replacing(moves: moves + autoFinishMoves())
        }
        return self
    }

    public func tapStock() -> GameState {
        if isWon || !board.canDraw() {
            return clearingSelection()
        }
        return play(.draw)
    }

    public func tapCard(_ pile: Pile, index: Int) -> GameState {
        if isWon {
            return self
        }
        let count = board.cardsIn(pile).count - index
        let tapped = Selection(pile: pile, count: count)
        if selection == tapped {
            return autoMove(tapped) ?? clearingSelection()
        }
        if let selection, selection.pile != pile,
            board.canMove(from: selection.pile, count: selection.count, to: pile, order: order)
        {
            return play(.transfer(from: selection.pile, count: selection.count, to: pile))
        }
        if !board.canPickUp(pile, count: count, order: order) {
            return clearingSelection()
        }
        if oneTapMove, let moved = autoMove(tapped) {
            return moved
        }
        var next = self
        next.selection = tapped
        return next
    }

    public func drop(from: Pile, index: Int, to: Pile) -> GameState {
        let count = board.cardsIn(from).count - index
        if isWon || from == to || !board.canMove(from: from, count: count, to: to, order: order) {
            return clearingSelection()
        }
        return play(.transfer(from: from, count: count, to: to))
    }

    public func tapEmptyPile(_ pile: Pile) -> GameState {
        guard let selection else {
            return self
        }
        if board.canMove(from: selection.pile, count: selection.count, to: pile, order: order) {
            return play(.transfer(from: selection.pile, count: selection.count, to: pile))
        }
        return clearingSelection()
    }

    public func undo() -> GameState {
        if moves.isEmpty || isWon {
            return clearingSelection()
        }
        return replacing(moves: Array(moves.dropLast()))
    }

    public func restart() -> GameState {
        replacing(moves: [])
    }

    public func destinationFor(_ selection: Selection) -> Pile? {
        var candidates: [Pile] = []
        if selection.count == 1, let card = board.cardsIn(selection.pile).last {
            candidates.append(.foundation(card.suit.rawValue))
        }
        let indices = board.tableau.indices
        candidates += indices.filter { !board.tableau[$0].cards.isEmpty }.map { Pile.tableau($0) }
        candidates += indices.filter { board.tableau[$0].cards.isEmpty }.map { Pile.tableau($0) }
        return candidates.first { candidate in
            board.canMove(from: selection.pile, count: selection.count, to: candidate, order: order)
                && !isPointless(candidate, for: selection)
        }
    }

    private func isPointless(_ candidate: Pile, for selection: Selection) -> Bool {
        guard case .tableau(let target) = candidate, case .tableau(let source) = selection.pile else {
            return false
        }
        return board.tableau[target].cards.isEmpty
            && board.tableau[source].faceUpFrom == 0
            && selection.count == board.tableau[source].cards.count
    }

    private func autoMove(_ selection: Selection) -> GameState? {
        destinationFor(selection).map { play(.transfer(from: selection.pile, count: selection.count, to: $0)) }
    }

    private func play(_ move: Move) -> GameState {
        replacing(moves: moves + [move])
    }

    private func replacing(moves: [Move]) -> GameState {
        GameState(start: start, drawMode: drawMode, moves: moves, selection: nil, oneTapMove: oneTapMove, order: order)
    }

    private func clearingSelection() -> GameState {
        var next = self
        next.selection = nil
        return next
    }
}
