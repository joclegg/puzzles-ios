import PuzzlesCore

public struct Mark: RawRepresentable, Sendable, Equatable {
    public let rawValue: Character

    public init?(rawValue: Character) {
        guard rawValue == emptyMark || isLetter(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }
}

public struct Change: Sendable, Equatable {
    public let cell: Int
    public let from: Character
    public let to: Character

    public init(cell: Int, from: Character, to: Character) {
        self.cell = cell
        self.from = from
        self.to = to
    }
}

public enum ChangeCodec {
    public static func encode(_ changes: [Change]) -> String {
        let marks = changes.compactMap { change -> (cell: Int, from: Mark, to: Mark)? in
            guard let from = Mark(rawValue: change.from), let to = Mark(rawValue: change.to) else {
                return nil
            }
            return (cell: change.cell, from: from, to: to)
        }
        return CellChangeCodec.encode(marks)
    }

    public static func decode(_ text: String) -> [Change]? {
        CellChangeCodec.decode(text, as: Mark.self)?.map { Change(cell: $0.cell, from: $0.from.rawValue, to: $0.to.rawValue) }
    }
}

public enum EntriesCodec {
    public static func encode(_ entries: [Character]) -> String {
        String(entries)
    }

    public static func decode(_ text: String, puzzle: Puzzle) -> [Character]? {
        let entries = Array(text)
        guard entries.count == puzzle.solution.count else {
            return nil
        }
        for (cell, entry) in entries.enumerated() {
            let valid = puzzle.isWhite[cell] ? entry == emptyMark || isLetter(entry) : entry == blockMark
            if !valid {
                return nil
            }
        }
        return entries
    }
}

public enum Arrow: Sendable {
    case up
    case down
    case left
    case right
}

public struct GameState: Sendable, Equatable {
    public var puzzle: Puzzle
    public var entries: [Character]
    public var changes: [Change]
    public var undone: [Change]
    public var selected: Int?
    public var isAcross: Bool
    public var skipFilledCells: Bool
    public var showMistakes: Bool
    public var mistakes: Int
    public var hints: Int

    public init(
        puzzle: Puzzle,
        entries: [Character]? = nil,
        changes: [Change] = [],
        undone: [Change] = [],
        selected: Int? = nil,
        isAcross: Bool = true,
        skipFilledCells: Bool = true,
        showMistakes: Bool = false,
        mistakes: Int = 0,
        hints: Int = 0
    ) {
        self.puzzle = puzzle
        self.entries = entries ?? GameState.emptyEntries(puzzle)
        self.changes = changes
        self.undone = undone
        self.selected = selected
        self.isAcross = isAcross
        self.skipFilledCells = skipFilledCells
        self.showMistakes = showMistakes
        self.mistakes = mistakes
        self.hints = hints
    }

    public static func emptyEntries(_ puzzle: Puzzle) -> [Character] {
        puzzle.solution.map { $0 == blockMark ? blockMark : emptyMark }
    }

    public static func start(puzzle: Puzzle, entries: [Character]? = nil, changes: [Change] = []) -> GameState {
        let state = GameState(puzzle: puzzle, entries: entries, changes: changes)
        let index = puzzle.words.indices.first { !state.isComplete(puzzle.words[$0]) } ?? 0
        guard puzzle.words.indices.contains(index) else {
            return state
        }
        return state.landOn(puzzle.words[index])
    }

    public var isSolved: Bool {
        puzzle.solution.indices.allSatisfy { !puzzle.isWhite[$0] || entries[$0] == puzzle.solution[$0] }
    }

    public var isFull: Bool {
        entries.allSatisfy { $0 != emptyMark }
    }

    public var wrongCells: Set<Int> {
        Set(entries.indices.filter { isLetter(entries[$0]) && entries[$0] != puzzle.solution[$0] })
    }

    public var shownWrongCells: Set<Int> {
        showMistakes ? wrongCells : []
    }

    public var currentWordIndex: Int? {
        guard let selected else {
            return nil
        }
        let primary = isAcross ? puzzle.acrossWord[selected] : puzzle.downWord[selected]
        return primary ?? (isAcross ? puzzle.downWord[selected] : puzzle.acrossWord[selected])
    }

    public var currentWord: Word? {
        currentWordIndex.map { puzzle.words[$0] }
    }

    public var highlightedCells: Set<Int> {
        Set(currentWord?.cells ?? [])
    }

    public func isComplete(_ word: Word) -> Bool {
        word.cells.allSatisfy { entries[$0] != emptyMark }
    }

    public func tapCell(_ cell: Int) -> GameState {
        guard puzzle.solution.indices.contains(cell), puzzle.isWhite[cell] else {
            return self
        }
        if selected == cell {
            return toggleDirection()
        }
        var next = self
        next.selected = cell
        if wordIndex(at: cell, across: isAcross) == nil {
            next.isAcross = !isAcross
        }
        return next
    }

    public func toggleDirection() -> GameState {
        guard let selected, wordIndex(at: selected, across: !isAcross) != nil else {
            return self
        }
        var next = self
        next.isAcross = !isAcross
        return next
    }

    public func arrow(_ arrow: Arrow) -> GameState {
        guard let selected else {
            return self
        }
        let horizontal = arrow == .left || arrow == .right
        if horizontal != isAcross && wordIndex(at: selected, across: horizontal) != nil {
            var next = self
            next.isAcross = horizontal
            return next
        }
        let size = puzzle.size
        var row = selected / size
        var column = selected % size
        while true {
            switch arrow {
            case .up: row -= 1
            case .down: row += 1
            case .left: column -= 1
            case .right: column += 1
            }
            guard (0..<size).contains(row), (0..<size).contains(column) else {
                return self
            }
            let cell = row * size + column
            if puzzle.isWhite[cell] {
                var next = self
                next.selected = cell
                if wordIndex(at: cell, across: isAcross) == nil {
                    next.isAcross = !isAcross
                }
                return next
            }
        }
    }

    public func nextClue() -> GameState {
        stepClue(by: 1)
    }

    public func previousClue() -> GameState {
        stepClue(by: -1)
    }

    public func selectWord(_ index: Int) -> GameState {
        guard puzzle.words.indices.contains(index) else {
            return self
        }
        return landOn(puzzle.words[index])
    }

    public func type(_ character: Character) -> GameState {
        let letter = Character(character.uppercased())
        guard isLetter(letter), let selected, !isSolved, let wordIndex = currentWordIndex else {
            return self
        }
        var next = set(cell: selected, to: letter)
        if next.showMistakes && letter != puzzle.solution[selected] && entries[selected] != letter {
            next.mistakes += 1
        }
        let word = puzzle.words[wordIndex]
        guard let position = word.cells.firstIndex(of: selected) else {
            return next
        }
        let later = word.cells[(position + 1)...]
        let target = skipFilledCells ? later.first { next.entries[$0] == emptyMark } : later.first
        if let target {
            next.selected = target
            return next
        }
        if next.isComplete(word) {
            if let following = next.nextEmptyWord(after: wordIndex) {
                return next.landOn(puzzle.words[following])
            }
            return next
        }
        next.selected = word.cells.last
        return next
    }

    public func backspace() -> GameState {
        guard let selected, !isSolved, let wordIndex = currentWordIndex else {
            return self
        }
        if entries[selected] != emptyMark {
            return set(cell: selected, to: emptyMark)
        }
        let word = puzzle.words[wordIndex]
        if let position = word.cells.firstIndex(of: selected), position > 0 {
            var next = self
            let target = word.cells[position - 1]
            next.selected = target
            return next.set(cell: target, to: emptyMark)
        }
        let previousIndex = (wordIndex - 1 + puzzle.words.count) % puzzle.words.count
        let previous = puzzle.words[previousIndex]
        guard let last = previous.cells.last else {
            return self
        }
        var next = self
        next.selected = last
        next.isAcross = previous.isAcross
        return next.set(cell: last, to: emptyMark)
    }

    public func undo() -> GameState {
        guard let last = changes.last, !isSolved else {
            return self
        }
        var next = self
        next.entries[last.cell] = last.from
        next.changes.removeLast()
        next.undone.append(last)
        next.selected = last.cell
        return next.facingWord(at: last.cell)
    }

    public func redo() -> GameState {
        guard let change = undone.last, !isSolved else {
            return self
        }
        var next = self
        next.entries[change.cell] = change.to
        next.changes.append(change)
        next.undone.removeLast()
        next.selected = change.cell
        return next.facingWord(at: change.cell)
    }

    public func revealLetter() -> GameState {
        guard let selected, !isSolved, entries[selected] != puzzle.solution[selected] else {
            return self
        }
        var next = set(cell: selected, to: puzzle.solution[selected])
        next.hints += 1
        return next
    }

    public func revealWord() -> GameState {
        guard let word = currentWord, !isSolved else {
            return self
        }
        var next = self
        var changed = false
        for cell in word.cells where next.entries[cell] != puzzle.solution[cell] {
            next = next.set(cell: cell, to: puzzle.solution[cell])
            changed = true
        }
        if changed {
            next.hints += 1
        }
        return next
    }

    public func revealSolution() -> GameState {
        var next = self
        next.entries = puzzle.solution
        next.selected = nil
        return next
    }

    public func restart() -> GameState {
        var next = GameState.start(puzzle: puzzle)
        next.skipFilledCells = skipFilledCells
        next.showMistakes = showMistakes
        return next
    }

    private func wordIndex(at cell: Int, across: Bool) -> Int? {
        across ? puzzle.acrossWord[cell] : puzzle.downWord[cell]
    }

    private func facingWord(at cell: Int) -> GameState {
        guard wordIndex(at: cell, across: isAcross) == nil else {
            return self
        }
        var next = self
        next.isAcross = !isAcross
        return next
    }

    private func stepClue(by step: Int) -> GameState {
        let count = puzzle.words.count
        guard count > 0 else {
            return self
        }
        let current = currentWordIndex ?? (step > 0 ? count - 1 : 0)
        let index = ((current + step) % count + count) % count
        return landOn(puzzle.words[index])
    }

    private func nextEmptyWord(after index: Int) -> Int? {
        let count = puzzle.words.count
        for offset in 1...count {
            let candidate = (index + offset) % count
            if !isComplete(puzzle.words[candidate]) {
                return candidate
            }
        }
        return nil
    }

    private func landOn(_ word: Word) -> GameState {
        var next = self
        next.isAcross = word.isAcross
        next.selected = word.cells.first { entries[$0] == emptyMark } ?? word.cells.first
        return next
    }

    private func set(cell: Int, to value: Character) -> GameState {
        guard entries[cell] != value else {
            return self
        }
        var next = self
        next.changes.append(Change(cell: cell, from: entries[cell], to: value))
        next.entries[cell] = value
        next.undone = []
        return next
    }
}
