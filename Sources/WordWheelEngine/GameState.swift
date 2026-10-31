public enum Guess: Sendable, Equatable {
    case found
    case bonus
    case already
    case notAWord
    case tooShort
}

public struct GameState: Sendable, Equatable {
    public var puzzle: Puzzle
    public var found: [String]
    public var bonus: [String]
    public private(set) var revealed: [Cell]
    public var wheel: String
    public var last: Guess?

    public init(
        puzzle: Puzzle,
        found: [String] = [],
        bonus: [String] = [],
        revealed: [Cell] = [],
        wheel: String? = nil,
        last: Guess? = nil
    ) {
        self.puzzle = puzzle
        self.found = found
        self.bonus = bonus
        var seen = Set<Cell>()
        self.revealed = revealed.filter { seen.insert($0).inserted }
        self.wheel = wheel ?? puzzle.letters
        self.last = last
    }

    public var isSolved: Bool {
        puzzle.crossword.words.allSatisfy(found.contains)
    }

    public var shownCells: Set<Cell> {
        var cells = Set(revealed)
        for placement in puzzle.crossword.placements where found.contains(placement.word) {
            cells.formUnion(placement.cells)
        }
        return cells
    }

    public func submit(_ word: String, words: WordList) -> GameState {
        if isSolved {
            return self
        }
        let guess = word.uppercased()
        var next = self
        if guess.count < minWord {
            next.last = .tooShort
        } else if found.contains(guess) || bonus.contains(guess) {
            next.last = .already
        } else if puzzle.crossword.words.contains(guess) {
            next.found.append(guess)
            next.last = .found
        } else if words.valid.contains(guess) && WordList.fits(guess, letters: puzzle.letters) {
            next.bonus.append(guess)
            next.last = .bonus
        } else {
            next.last = .notAWord
        }
        return next
    }

    public func revealAll() -> GameState {
        var next = self
        next.found = puzzle.crossword.words
        next.last = nil
        return next
    }

    public func shuffle(order: [Int]) -> GameState {
        let letters = Array(wheel)
        var next = self
        next.wheel = String(order.map { letters[$0] })
        next.last = nil
        return next
    }

    public func reveal(pick: ([Cell]) -> Cell?) -> GameState {
        let shown = shownCells
        let hidden = puzzle.crossword.letters.keys
            .filter { !shown.contains($0) }
            .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        guard let cell = pick(hidden) else {
            return self
        }
        var next = self
        if !revealed.contains(cell) {
            next.revealed.append(cell)
        }
        next.last = nil
        let shownNow = next.shownCells
        let completed = puzzle.crossword.placements
            .filter { placement in
                !found.contains(placement.word) && placement.cells.allSatisfy(shownNow.contains)
            }
            .map(\.word)
        next.found = found + completed
        return next
    }
}
