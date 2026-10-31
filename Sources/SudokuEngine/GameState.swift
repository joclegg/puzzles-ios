public enum InputMode: String, Sendable, CaseIterable {
    case cellFirst = "CELL_FIRST"
    case digitFirst = "DIGIT_FIRST"
}

public enum Highlight: Sendable, Equatable {
    case selected
    case sameDigit
    case noteMatch
    case peer
    case none
}

public enum HighlightStyle: String, Sendable, CaseIterable {
    case cell = "CELL"
    case number = "NUMBER"
    case off = "OFF"
}

public struct CellChange: Sendable, Equatable {
    public let cell: Int
    public let value: Int
    public let notes: Int

    public init(cell: Int, value: Int, notes: Int) {
        self.cell = cell
        self.value = value
        self.notes = notes
    }
}

public typealias Move = [CellChange]

public enum MoveCodec {
    public static func encode(_ moves: [Move]) -> String {
        moves.map { move in
            move.map { "\($0.cell):\($0.value):\($0.notes)" }.joined(separator: ",")
        }.joined(separator: ";")
    }

    public static func decode(_ text: String) throws -> [Move] {
        try parts(text, separator: ";").filter { !$0.isEmpty }.map { move in
            try parts(move, separator: ",").map { change in
                let fields = try parts(change, separator: ":").map(integer)
                if fields.count < 3 {
                    throw CodecError.malformed
                }
                return CellChange(cell: fields[0], value: fields[1], notes: fields[2])
            }
        }
    }
}

public enum MistakeCheck: String, Sendable, CaseIterable {
    case off = "OFF"
    case blockClashes = "BLOCK_CLASHES"
    case showWrong = "SHOW_WRONG"
}

public struct Rejection: Sendable, Equatable {
    public let cell: Int
    public let clashes: Set<Int>

    public init(cell: Int, clashes: Set<Int>) {
        self.cell = cell
        self.clashes = clashes
    }
}

public struct PlayOptions: Sendable, Equatable {
    public var highlightHouses: Bool
    public var highlightCage: Bool
    public var sameNumberStyle: HighlightStyle
    public var notesStyle: HighlightStyle
    public var autoRemoveNotes: Bool
    public var highlightLastPlaced: Bool

    public init(
        highlightHouses: Bool = true,
        highlightCage: Bool = true,
        sameNumberStyle: HighlightStyle = .cell,
        notesStyle: HighlightStyle = .cell,
        autoRemoveNotes: Bool = true,
        highlightLastPlaced: Bool = true
    ) {
        self.highlightHouses = highlightHouses
        self.highlightCage = highlightCage
        self.sameNumberStyle = sameNumberStyle
        self.notesStyle = notesStyle
        self.autoRemoveNotes = autoRemoveNotes
        self.highlightLastPlaced = highlightLastPlaced
    }
}

public struct GameState: Sendable, Equatable {
    public var puzzle: Puzzle
    public var values: [Int]
    public var notes: [Int]
    public var selected: Int?
    public var activeDigit: Int?
    public var inputMode: InputMode
    public var notesMode: Bool
    public var mistakeCheck: MistakeCheck
    public var mistakes: Int
    public var undoStack: [Move]
    public var redoStack: [Move]
    public var options: PlayOptions
    public var rejected: Rejection?
    public var eraserActive: Bool
    public var lastPlaced: Int?
    public var marked: Set<Int>
    public var markActive: Bool

    public init(
        puzzle: Puzzle,
        values: [Int]? = nil,
        notes: [Int]? = nil,
        selected: Int? = nil,
        activeDigit: Int? = nil,
        inputMode: InputMode = .cellFirst,
        notesMode: Bool = false,
        mistakeCheck: MistakeCheck = .showWrong,
        mistakes: Int = 0,
        undoStack: [Move] = [],
        redoStack: [Move] = [],
        options: PlayOptions = PlayOptions(),
        rejected: Rejection? = nil,
        eraserActive: Bool = false,
        lastPlaced: Int? = nil,
        marked: Set<Int> = [],
        markActive: Bool = false
    ) {
        self.puzzle = puzzle
        self.values = values ?? puzzle.givens
        self.notes = notes ?? [Int](repeating: 0, count: puzzle.givens.count)
        self.selected = selected
        self.activeDigit = activeDigit
        self.inputMode = inputMode
        self.notesMode = notesMode
        self.mistakeCheck = mistakeCheck
        self.mistakes = mistakes
        self.undoStack = undoStack
        self.redoStack = redoStack
        self.options = options
        self.rejected = rejected
        self.eraserActive = eraserActive
        self.lastPlaced = lastPlaced
        self.marked = marked
        self.markActive = markActive
    }

    public var effectiveMistakeCheck: MistakeCheck {
        mistakeCheck == .showWrong && puzzle.solution == nil ? .blockClashes : mistakeCheck
    }

    public var checking: Bool {
        effectiveMistakeCheck == .showWrong
    }

    public var countsMistakes: Bool {
        effectiveMistakeCheck != .off
    }

    public var isComplete: Bool {
        if values.contains(0) {
            return false
        }
        if let solution = puzzle.solution {
            return solution == values
        }
        return conflicts(values: values, cages: puzzle.cages).isEmpty
    }

    public func isGiven(_ cell: Int) -> Bool {
        puzzle.givens[cell] != 0
    }

    public func isWrong(_ cell: Int) -> Bool {
        guard let solution = puzzle.solution else {
            return false
        }
        return checking && !isGiven(cell) && values[cell] != 0 && values[cell] != solution[cell]
    }

    public func isCageWrong(_ cage: Cage) -> Bool {
        if !checking || cage.cells.contains(where: { values[$0] == 0 }) {
            return false
        }
        let digits = cage.cells.map { values[$0] }
        return digits.reduce(0, +) != cage.sum || Set(digits).count != digits.count
    }

    public var highlightDigit: Int? {
        switch inputMode {
        case .digitFirst:
            return activeDigit
        case .cellFirst:
            guard let selected, values[selected] != 0 else {
                return nil
            }
            return values[selected]
        }
    }

    public func highlight(_ cell: Int) -> Highlight {
        let digit = highlightDigit
        let shownSelection = !options.highlightLastPlaced && selected == lastPlaced ? nil : selected
        if cell == shownSelection {
            return .selected
        }
        if let digit {
            if options.sameNumberStyle == .cell && values[cell] == digit {
                return .sameDigit
            }
            if options.notesStyle == .cell && values[cell] == 0 && notes[cell] & digitBit(digit) != 0 {
                return .noteMatch
            }
        }
        if let shownSelection, isHighlightedPeer(shownSelection, cell) {
            return .peer
        }
        return .none
    }

    public func isNumberHighlighted(_ cell: Int) -> Bool {
        options.sameNumberStyle == .number && highlightDigit != nil && values[cell] == highlightDigit
    }

    public var noteHighlightDigit: Int? {
        options.notesStyle == .number ? highlightDigit : nil
    }

    public func digitCount(_ digit: Int) -> Int {
        values.count { $0 == digit }
    }

    public func isDigitDone(_ digit: Int) -> Bool {
        values.indices.count { values[$0] == digit && !isWrong($0) } >= puzzle.grid.size
    }

    public func tapCell(_ cell: Int) -> GameState {
        if isComplete {
            return self
        }
        var next = self
        next.selected = cell
        next.rejected = nil
        if inputMode != .digitFirst {
            return next
        }
        if markActive {
            return next.toggleMark(cell)
        }
        if eraserActive {
            return next.clear(cell)
        }
        if let activeDigit {
            return next.enter(cell, activeDigit)
        }
        return next
    }

    public func tapDigit(_ digit: Int) -> GameState {
        if isComplete {
            return self
        }
        var next = self
        next.rejected = nil
        switch inputMode {
        case .digitFirst:
            next.markActive = false
            next.activeDigit = activeDigit == digit ? nil : digit
            next.eraserActive = false
            return next
        case .cellFirst:
            guard let selected else {
                return self
            }
            return next.enter(selected, digit)
        }
    }

    public func erase() -> GameState {
        if isComplete {
            return self
        }
        if inputMode == .digitFirst {
            var next = self
            next.eraserActive = !eraserActive
            next.markActive = false
            next.activeDigit = nil
            next.rejected = nil
            return next
        }
        guard let selected else {
            return self
        }
        return clear(selected)
    }

    public func mark() -> GameState {
        if isComplete {
            return self
        }
        if inputMode == .digitFirst {
            var next = self
            next.markActive = !markActive
            next.eraserActive = false
            next.activeDigit = nil
            next.rejected = nil
            return next
        }
        guard let selected else {
            return self
        }
        return toggleMark(selected)
    }

    private func toggleMark(_ cell: Int) -> GameState {
        var next = self
        if marked.contains(cell) {
            next.marked.remove(cell)
        } else {
            next.marked.insert(cell)
        }
        return next
    }

    private func clear(_ cell: Int) -> GameState {
        if isGiven(cell) || (values[cell] == 0 && notes[cell] == 0) {
            return self
        }
        var next = self
        next.values[cell] = 0
        next.notes[cell] = 0
        next.rejected = nil
        return record(next)
    }

    public func undo() -> GameState {
        if isComplete {
            return self
        }
        guard let last = undoStack.last else {
            return self
        }
        var next = applied(last)
        next.undoStack = Array(undoStack.dropLast())
        next.redoStack = redoStack + [snapshot(last)]
        return next
    }

    public func redo() -> GameState {
        if isComplete {
            return self
        }
        guard let move = redoStack.last else {
            return self
        }
        var next = applied(move)
        next.undoStack = undoStack + [snapshot(move)]
        next.redoStack = Array(redoStack.dropLast())
        return next
    }

    private func snapshot(_ move: Move) -> Move {
        move.map { CellChange(cell: $0.cell, value: values[$0.cell], notes: notes[$0.cell]) }
    }

    private func applied(_ move: Move) -> GameState {
        var next = self
        for change in move {
            next.values[change.cell] = change.value
            next.notes[change.cell] = change.notes
        }
        next.rejected = nil
        next.lastPlaced = nil
        return next
    }

    public func restart() -> GameState {
        GameState(puzzle: puzzle, inputMode: inputMode, mistakeCheck: mistakeCheck, options: options)
    }

    public func placeHint(_ hint: Hint) -> GameState {
        var next = self
        next.notesMode = false
        next.selected = hint.cell
        return next.enter(hint.cell, hint.digit)
    }

    public func revealSolution() -> GameState {
        guard let solution = puzzle.solution else {
            return self
        }
        var next = self
        next.values = solution
        next.notes = notes.map { _ in 0 }
        next.selected = nil
        next.activeDigit = nil
        next.rejected = nil
        return next
    }

    public func toggleNotesMode() -> GameState {
        var next = self
        next.notesMode = !notesMode
        return next
    }

    public func withInputMode(_ mode: InputMode) -> GameState {
        var next = self
        next.inputMode = mode
        next.activeDigit = nil
        next.eraserActive = false
        return next
    }

    private func enter(_ cell: Int, _ digit: Int) -> GameState {
        if isGiven(cell) {
            return self
        }
        var next = self
        if notesMode {
            if values[cell] != 0 {
                return self
            }
            next.notes[cell] = notes[cell] ^ digitBit(digit)
            next.lastPlaced = cell
            return record(next)
        }
        if values[cell] == digit {
            next.values[cell] = 0
            next.lastPlaced = nil
            return record(next)
        }
        if effectiveMistakeCheck == .blockClashes {
            let clashes = Set(values.indices.filter { isPeer(cell, $0) && values[$0] == digit })
            if !clashes.isEmpty {
                next.rejected = Rejection(cell: cell, clashes: clashes)
                next.mistakes = mistakes + 1
                return next
            }
        }
        let wrong = checking && puzzle.solution?[cell] != digit
        let clearBit = ~digitBit(digit)
        next.notes = notes.indices.map { index in
            if index == cell {
                return 0
            }
            if options.autoRemoveNotes && isPeer(cell, index) {
                return notes[index] & clearBit
            }
            return notes[index]
        }
        next.values[cell] = digit
        next.mistakes = mistakes + (wrong ? 1 : 0)
        next.lastPlaced = cell
        return record(next)
    }

    private func record(_ next: GameState) -> GameState {
        let changed = values.indices.filter { values[$0] != next.values[$0] || notes[$0] != next.notes[$0] }
        var result = next
        result.undoStack = undoStack + [changed.map { CellChange(cell: $0, value: values[$0], notes: notes[$0]) }]
        result.redoStack = []
        return result
    }

    private func isPeer(_ a: Int, _ b: Int) -> Bool {
        a != b && (sharesHouse(a, b) || sharesCage(a, b))
    }

    private func isHighlightedPeer(_ a: Int, _ b: Int) -> Bool {
        a != b && ((options.highlightHouses && sharesHouse(a, b)) || (options.highlightCage && sharesCage(a, b)))
    }

    private func sharesHouse(_ a: Int, _ b: Int) -> Bool {
        puzzle.grid.sharesHouse(a, b)
    }

    private func sharesCage(_ a: Int, _ b: Int) -> Bool {
        puzzle.cageIndexByCell[a] != noCage && puzzle.cageIndexByCell[a] == puzzle.cageIndexByCell[b]
    }
}

public func conflicts(values: [Int], cages: [Cage] = []) -> Set<Int> {
    var bad = Set<Int>()
    let groups = Grid.forCellCount(values.count).houses + cages.map(\.cells)
    for group in groups {
        let filled = group.filter { values[$0] != 0 }
        let byDigit = Dictionary(grouping: filled) { values[$0] }
        for cells in byDigit.values where cells.count > 1 {
            bad.formUnion(cells)
        }
    }
    for cage in cages {
        let filled = cage.cells.filter { values[$0] != 0 }
        let total = filled.reduce(0) { $0 + values[$1] }
        if total > cage.sum || (filled.count == cage.cells.count && total != cage.sum) {
            bad.formUnion(filled)
        }
    }
    return bad
}

public struct GameTimer: Sendable, Equatable {
    public var accumulatedMs: Int64
    public var runningSinceMs: Int64?

    public init(accumulatedMs: Int64 = 0, runningSinceMs: Int64? = nil) {
        self.accumulatedMs = accumulatedMs
        self.runningSinceMs = runningSinceMs
    }

    public func start(nowMs: Int64) -> GameTimer {
        if runningSinceMs != nil {
            return self
        }
        return GameTimer(accumulatedMs: accumulatedMs, runningSinceMs: nowMs)
    }

    public func pause(nowMs: Int64) -> GameTimer {
        guard let runningSinceMs else {
            return self
        }
        return GameTimer(accumulatedMs: accumulatedMs + (nowMs - runningSinceMs))
    }

    public func elapsedMs(nowMs: Int64) -> Int64 {
        guard let runningSinceMs else {
            return accumulatedMs
        }
        return accumulatedMs + (nowMs - runningSinceMs)
    }
}
