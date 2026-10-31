public struct Change: Sendable, Equatable {
    public let cell: Int
    public let fromValue: Int
    public let fromNotes: Int
    public let toValue: Int
    public let toNotes: Int
    public let clearedNotes: [Int]

    public init(
        cell: Int,
        fromValue: Int,
        fromNotes: Int,
        toValue: Int,
        toNotes: Int,
        clearedNotes: [Int] = []
    ) {
        self.cell = cell
        self.fromValue = fromValue
        self.fromNotes = fromNotes
        self.toValue = toValue
        self.toNotes = toNotes
        self.clearedNotes = clearedNotes
    }
}

public enum ChangeCodec {
    private static let changeFields = 5

    public static func encode(_ changes: [Change]) -> String {
        changes.map { change in
            let base = "\(change.cell),\(change.fromValue),\(change.fromNotes),\(change.toValue),\(change.toNotes)"
            if change.clearedNotes.isEmpty {
                return base
            }
            return base + "," + change.clearedNotes.map(String.init).joined(separator: ":")
        }.joined(separator: ";")
    }

    public static func decode(_ text: String) -> [Change]? {
        var changes: [Change] = []
        for entry in text.split(separator: ";") {
            let parts = entry.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= changeFields else {
                return nil
            }
            let fields = parts.prefix(changeFields).compactMap { Int($0) }
            guard fields.count == changeFields else {
                return nil
            }
            var cleared: [Int] = []
            if parts.count > changeFields {
                for part in parts[changeFields].split(separator: ":", omittingEmptySubsequences: false) {
                    guard let cell = Int(part) else {
                        return nil
                    }
                    cleared.append(cell)
                }
            }
            changes.append(
                Change(
                    cell: fields[0],
                    fromValue: fields[1],
                    fromNotes: fields[2],
                    toValue: fields[3],
                    toNotes: fields[4],
                    clearedNotes: cleared
                )
            )
        }
        return changes
    }
}

public enum InputMode: String, Sendable, CaseIterable {
    case cellFirst
    case digitFirst
}

public enum MistakeCheck: String, Sendable, CaseIterable {
    case off
    case blockClashes
    case showWrong
}

public struct GameState: Sendable, Equatable {
    public var puzzle: Puzzle
    public var values: [Int]
    public var notes: [Int]
    public var changes: [Change]
    public var selected: Int?
    public var notesMode: Bool
    public var inputMode: InputMode
    public var mistakeCheck: MistakeCheck
    public var activeDigit: Int?
    public var eraserActive: Bool
    public var mistakes: Int
    public var rejected: Int?
    public var autoRemoveNotes: Bool
    public var undone: [Change]
    public var marked: Set<Int>
    public var markActive: Bool

    public init(
        puzzle: Puzzle,
        values: [Int]? = nil,
        notes: [Int]? = nil,
        changes: [Change] = [],
        selected: Int? = nil,
        notesMode: Bool = false,
        inputMode: InputMode = .cellFirst,
        mistakeCheck: MistakeCheck = .showWrong,
        activeDigit: Int? = nil,
        eraserActive: Bool = false,
        mistakes: Int = 0,
        rejected: Int? = nil,
        autoRemoveNotes: Bool = true,
        undone: [Change] = [],
        marked: Set<Int> = [],
        markActive: Bool = false
    ) {
        self.puzzle = puzzle
        self.values = values ?? GameState.startValues(puzzle)
        self.notes = notes ?? [Int](repeating: 0, count: puzzle.solution.count)
        self.changes = changes
        self.selected = selected
        self.notesMode = notesMode
        self.inputMode = inputMode
        self.mistakeCheck = mistakeCheck
        self.activeDigit = activeDigit
        self.eraserActive = eraserActive
        self.mistakes = mistakes
        self.rejected = rejected
        self.autoRemoveNotes = autoRemoveNotes
        self.undone = undone
        self.marked = marked
        self.markActive = markActive
    }

    public var isSolved: Bool {
        values == puzzle.solution
    }

    public var wrongCells: Set<Int> {
        Set(values.indices.filter { values[$0] != 0 && values[$0] != puzzle.solution[$0] })
    }

    public var brokenRuns: [Run] {
        puzzle.runs.filter { run in
            let placed = run.cells.map { values[$0] }.filter { $0 != 0 }
            let total = placed.reduce(0, +)
            return placed.count != Set(placed).count || total > run.sum
                || (placed.count == run.cells.count && total != run.sum)
        }
    }

    public func isGiven(_ cell: Int) -> Bool {
        puzzle.givens.contains(cell)
    }

    public func selectedCombinations() -> [(run: Run, masks: [Int])] {
        guard let selected else {
            return []
        }
        return (puzzle.runsOf[selected] ?? []).map { run in
            let placed = run.cells.filter { values[$0] != 0 }.reduce(0) { $0 | Combinations.bit(values[$1]) }
            return (run, Combinations.masks(length: run.cells.count, sum: run.sum).filter { $0 & placed == placed })
        }
    }

    public var shownWrongCells: Set<Int> {
        switch mistakeCheck {
        case .showWrong:
            wrongCells.union(brokenRunFilledCells)
        case .blockClashes:
            Set(brokenRunFilledCells)
        case .off:
            []
        }
    }

    public func isDigitDone(_ digit: Int) -> Bool {
        let needed = puzzle.solution.count { $0 == digit }
        return needed > 0 && values.indices.count { values[$0] == digit && values[$0] == puzzle.solution[$0] } == needed
    }

    public func tapCell(_ cell: Int) -> GameState {
        if !puzzle.isWhite[cell] {
            return self
        }
        var selectedHere = self
        selectedHere.selected = cell
        selectedHere.rejected = nil
        if inputMode == .digitFirst && markActive && !isSolved {
            return selectedHere.toggleMark(cell)
        }
        if inputMode == .cellFirst || isSolved || isGiven(cell) {
            return selectedHere
        }
        if eraserActive {
            return selectedHere.set(cell: cell, value: 0, cellNotes: 0)
        }
        if let activeDigit {
            return selectedHere.place(cell: cell, digit: activeDigit)
        }
        return selectedHere
    }

    public func tapDigit(_ digit: Int) -> GameState {
        var next = self
        if inputMode == .digitFirst {
            next.activeDigit = activeDigit == digit ? nil : digit
            next.eraserActive = false
            next.markActive = false
            next.rejected = nil
            return next
        }
        guard let selected, !isSolved, !isGiven(selected) else {
            return self
        }
        next.rejected = nil
        return next.place(cell: selected, digit: digit)
    }

    public func erase() -> GameState {
        if inputMode == .digitFirst {
            var next = self
            next.eraserActive = !eraserActive
            next.markActive = false
            next.activeDigit = nil
            next.rejected = nil
            return next
        }
        guard let selected, !isSolved, !isGiven(selected) else {
            return self
        }
        return set(cell: selected, value: 0, cellNotes: 0)
    }

    public func mark() -> GameState {
        if isSolved {
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

    public func withInputMode(_ mode: InputMode) -> GameState {
        var next = self
        next.inputMode = mode
        next.activeDigit = nil
        next.eraserActive = false
        next.markActive = false
        next.rejected = nil
        return next
    }

    public func placeHint(_ hint: Hint) -> GameState {
        var next = self
        next.notesMode = false
        next.selected = hint.cell
        next.rejected = nil
        return next.place(cell: hint.cell, digit: hint.digit)
    }

    public func revealSolution() -> GameState {
        var next = self
        next.values = puzzle.solution
        next.notes = notes.map { _ in 0 }
        next.selected = nil
        next.rejected = nil
        return next
    }

    public func toggleNotes() -> GameState {
        var next = self
        next.notesMode = !notesMode
        return next
    }

    public func undo() -> GameState {
        guard let last = changes.last, !isSolved else {
            return self
        }
        var next = self
        next.values[last.cell] = last.fromValue
        next.notes[last.cell] = last.fromNotes
        for other in last.clearedNotes {
            next.notes[other] |= Combinations.bit(last.toValue)
        }
        next.changes.removeLast()
        next.selected = last.cell
        next.undone.append(last)
        return next
    }

    public func redo() -> GameState {
        guard let change = undone.last, !isSolved else {
            return self
        }
        var next = self
        next.values[change.cell] = change.toValue
        next.notes = applyNotes(change)
        next.changes.append(change)
        next.selected = change.cell
        next.undone.removeLast()
        return next
    }

    public func restart() -> GameState {
        GameState(puzzle: puzzle, inputMode: inputMode, mistakeCheck: mistakeCheck, autoRemoveNotes: autoRemoveNotes)
    }

    public static func startValues(_ puzzle: Puzzle) -> [Int] {
        puzzle.solution.enumerated().map { cell, digit in
            puzzle.givens.contains(cell) ? digit : 0
        }
    }

    public static func replay(puzzle: Puzzle, changes: [Change]) -> GameState {
        changes.reduce(GameState(puzzle: puzzle)) { state, change in
            var next = state
            next.values[change.cell] = change.toValue
            next.notes = state.applyNotes(change)
            next.changes.append(change)
            return next
        }
    }

    private var brokenRunFilledCells: [Int] {
        brokenRuns.flatMap { run in run.cells.filter { values[$0] != 0 } }
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

    private func place(cell: Int, digit: Int) -> GameState {
        if notesMode {
            if values[cell] != 0 {
                return self
            }
            return set(cell: cell, value: 0, cellNotes: notes[cell] ^ Combinations.bit(digit))
        }
        if values[cell] == digit {
            return set(cell: cell, value: 0, cellNotes: notes[cell])
        }
        switch mistakeCheck {
        case .blockClashes:
            let clashes = (puzzle.runsOf[cell] ?? []).contains { run in
                run.cells.contains { $0 != cell && values[$0] == digit }
            }
            if clashes {
                var next = self
                next.rejected = cell
                next.mistakes = mistakes + 1
                return next
            }
            return set(cell: cell, value: digit, cellNotes: 0)
        case .showWrong:
            var placed = set(cell: cell, value: digit, cellNotes: 0)
            if digit != puzzle.solution[cell] {
                placed.mistakes = mistakes + 1
            }
            return placed
        case .off:
            return set(cell: cell, value: digit, cellNotes: 0)
        }
    }

    private func set(cell: Int, value: Int, cellNotes: Int) -> GameState {
        if values[cell] == value && notes[cell] == cellNotes {
            return self
        }
        var cleared: [Int] = []
        if value != 0 && autoRemoveNotes {
            for other in (puzzle.runsOf[cell] ?? []).flatMap(\.cells) {
                if other != cell && notes[other] & Combinations.bit(value) != 0 && !cleared.contains(other) {
                    cleared.append(other)
                }
            }
        }
        let change = Change(
            cell: cell,
            fromValue: values[cell],
            fromNotes: notes[cell],
            toValue: value,
            toNotes: cellNotes,
            clearedNotes: cleared
        )
        var next = self
        next.values[cell] = value
        next.notes = applyNotes(change)
        next.changes.append(change)
        next.undone = []
        return next
    }

    private func applyNotes(_ change: Change) -> [Int] {
        var result = notes
        result[change.cell] = change.toNotes
        for other in change.clearedNotes {
            result[other] &= ~Combinations.bit(change.toValue)
        }
        return result
    }
}

public struct GameTimer: Sendable, Equatable {
    public let accumulatedMs: Int64
    public let runningSinceMs: Int64?

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
