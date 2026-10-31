public enum Hint: Sendable, Equatable {
    case transfer(selection: Selection, to: Pile)
    case draw
}

extension GameState {
    public func findHint() -> Hint? {
        if isWon {
            return nil
        }
        var options: [(selection: Selection, rank: Int)] = []
        if !board.waste.isEmpty {
            options.append((Selection(pile: .waste, count: 1), 1))
        }
        for (index, column) in board.tableau.enumerated() {
            for start in stride(from: column.faceUpFrom, to: column.cards.count, by: 1) {
                let rank: Int
                if start == column.faceUpFrom && start > 0 {
                    rank = 2
                } else if start == column.cards.count - 1 {
                    rank = 0
                } else {
                    rank = -1
                }
                options.append((Selection(pile: .tableau(index), count: column.cards.count - start), rank))
            }
        }
        var best: (hint: Hint, score: Int)?
        for option in options {
            guard let to = destinationFor(option.selection) else {
                continue
            }
            var score = option.rank
            if case .foundation = to {
                score = 3
            }
            if score >= 1 && score > (best?.score ?? 0) {
                best = (.transfer(selection: option.selection, to: to), score)
            }
        }
        if let best {
            return best.hint
        }
        return board.canDraw() ? .draw : nil
    }
}
