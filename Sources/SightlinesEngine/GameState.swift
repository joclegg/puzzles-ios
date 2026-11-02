import PuzzlesCore

public struct Change: Sendable, Equatable {
    public let cell: Int
    public let from: Dot
    public let to: Dot

    public init(cell: Int, from: Dot, to: Dot) {
        self.cell = cell
        self.from = from
        self.to = to
    }
}

public enum ChangeCodec {
    public static func encode(_ changes: [Change]) -> String {
        CellChangeCodec.encode(changes.map { (cell: $0.cell, from: $0.from, to: $0.to) })
    }

    public static func decode(_ text: String) -> [Change]? {
        CellChangeCodec.decode(text, as: Dot.self)?.map { Change(cell: $0.cell, from: $0.from, to: $0.to) }
    }
}

public enum Hint: Sendable, Equatable {
    case mistake(cells: [Int])
    case next(deduction: Deduction, cells: [Int])

    public var cells: [Int] {
        switch self {
        case .mistake(let cells):
            cells
        case .next(_, let cells):
            cells
        }
    }
}

public struct GameState: Sendable, Equatable {
    private static let percent = 100

    public var puzzle: Puzzle
    public var grid: Grid
    public var changes: [Change]
    public var hint: Hint?

    public init(puzzle: Puzzle, grid: Grid? = nil, changes: [Change] = [], hint: Hint? = nil) {
        self.puzzle = puzzle
        self.grid = grid ?? puzzle.givens
        self.changes = changes
        self.hint = hint
    }

    public static func replay(puzzle: Puzzle, changes: [Change]) -> GameState {
        let grid = changes.reduce(puzzle.givens) { $0.with(cell: $1.cell, dot: $1.to) }
        return GameState(puzzle: puzzle, grid: grid, changes: changes)
    }

    public var isSolved: Bool {
        grid == puzzle.solution
    }

    public var progressPercent: Int {
        let open = grid.dots.indices.count { !puzzle.isGiven($0) }
        let filled = grid.dots.indices.count { !puzzle.isGiven($0) && grid.dots[$0] != .empty }
        return open == 0 ? GameState.percent : filled * GameState.percent / open
    }

    public var brokenCells: Set<Int> {
        puzzle.brokenCells(grid)
    }

    public func tap(_ cell: Int) -> GameState {
        changing(cell) { $0.next }
    }

    public func paint(_ cell: Int, colour: Dot) -> GameState {
        changing(cell) { $0 == colour ? .empty : colour }
    }

    public func undo() -> GameState {
        var next = self
        next.hint = nil
        guard !isSolved, let last = changes.last else {
            return next
        }
        next.grid = grid.with(cell: last.cell, dot: last.from)
        next.changes.removeLast()
        return next
    }

    public func restart() -> GameState {
        GameState(puzzle: puzzle)
    }

    public func revealSolution() -> GameState {
        var next = self
        next.grid = puzzle.solution
        next.hint = nil
        return next
    }

    public func withHint() -> GameState {
        if isSolved {
            return self
        }
        var next = self
        let mistakes = grid.dots.indices.filter { grid.dots[$0] != .empty && grid.dots[$0] != puzzle.solution.dots[$0] }
        if !mistakes.isEmpty {
            next.hint = .mistake(cells: mistakes)
        } else if let deduction = Solver.next(grid, numbers: puzzle.numbers) {
            let sight = Direction.allCases.flatMap { grid.ray(deduction.source, direction: $0) } + [deduction.source]
            next.hint = .next(deduction: deduction, cells: sight)
        } else {
            next.hint = nil
        }
        return next
    }

    private func changing(_ cell: Int, to change: (Dot) -> Dot) -> GameState {
        var next = self
        next.hint = nil
        if isSolved || puzzle.isGiven(cell) {
            return next
        }
        let from = grid.dots[cell]
        let to = change(from)
        if to == from {
            return next
        }
        next.grid = grid.with(cell: cell, dot: to)
        next.changes.append(Change(cell: cell, from: from, to: to))
        return next
    }
}
