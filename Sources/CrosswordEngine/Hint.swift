public struct Hint: Sendable, Equatable {
    public let cell: Int
    public let letter: Character
    public let message: String

    public init(cell: Int, letter: Character, message: String) {
        self.cell = cell
        self.letter = letter
        self.message = message
    }
}

extension GameState {
    public func findHint() -> Hint? {
        if let wrong = entries.indices.first(where: { isLetter(entries[$0]) && entries[$0] != puzzle.solution[$0] }) {
            return Hint(cell: wrong, letter: puzzle.solution[wrong], message: "This letter is wrong.")
        }
        let count = puzzle.words.count
        guard count > 0 else {
            return nil
        }
        let start = currentWordIndex ?? 0
        for offset in 0..<count {
            let word = puzzle.words[(start + offset) % count]
            if let cell = word.cells.first(where: { entries[$0] == emptyMark }) {
                let letter = puzzle.solution[cell]
                return Hint(cell: cell, letter: letter, message: "Try \(letter) here.")
            }
        }
        return nil
    }

    public func pointHint(_ hint: Hint) -> GameState {
        var next = self
        next.jumpedFrom = nil
        next.selected = hint.cell
        next.hints += 1
        return next.facingWord(at: hint.cell)
    }

    public func placeHint(_ hint: Hint) -> GameState {
        var next = set(cell: hint.cell, to: hint.letter)
        next.jumpedFrom = nil
        next.selected = hint.cell
        next.hints += 1
        return next.facingWord(at: hint.cell)
    }
}
