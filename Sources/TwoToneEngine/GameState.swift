public struct Change: Sendable, Equatable {
    public let cell: Int
    public let from: Tile
    public let to: Tile

    public init(cell: Int, from: Tile, to: Tile) {
        self.cell = cell
        self.from = from
        self.to = to
    }
}

public enum ChangeCodec {
    public static func encode(_ changes: [Change]) -> String {
        changes.map { "\($0.cell)\($0.from.code)\($0.to.code)" }.joined(separator: ",")
    }

    public static func decode(_ text: String) -> [Change]? {
        var changes: [Change] = []
        for part in text.split(separator: ",") {
            guard part.count >= 2,
                let cell = Int(part.dropLast(2)),
                let from = Tile(rawValue: part[part.index(part.endIndex, offsetBy: -2)]),
                let to = Tile(rawValue: part[part.index(before: part.endIndex)])
            else {
                return nil
            }
            changes.append(Change(cell: cell, from: from, to: to))
        }
        return changes
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
        let grid = changes.reduce(puzzle.givens) { $0.with(cell: $1.cell, tile: $1.to) }
        return GameState(puzzle: puzzle, grid: grid, changes: changes)
    }

    public var isSolved: Bool {
        grid == puzzle.solution
    }

    public var progressPercent: Int {
        let open = puzzle.givens.tiles.count { $0 == .empty }
        let filled = grid.tiles.indices.count { !puzzle.isGiven($0) && grid.tiles[$0] != .empty }
        return open == 0 ? GameState.percent : filled * GameState.percent / open
    }

    public var brokenCells: Set<Int> {
        grid.brokenCells()
    }

    public func tap(_ cell: Int) -> GameState {
        changing(cell) { $0.next }
    }

    public func paint(_ cell: Int, colour: Tile) -> GameState {
        changing(cell) { $0 == colour ? .empty : colour }
    }

    public func undo() -> GameState {
        var next = self
        next.hint = nil
        guard !isSolved, let last = changes.last else {
            return next
        }
        next.grid = grid.with(cell: last.cell, tile: last.from)
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
        let mistakes = grid.tiles.indices.filter { grid.tiles[$0] != .empty && grid.tiles[$0] != puzzle.solution.tiles[$0] }
        if !mistakes.isEmpty {
            next.hint = .mistake(cells: mistakes)
        } else if let deduction = Solver.next(grid) {
            next.hint = .next(deduction: deduction, cells: grid.cellsOf(deduction.line))
        } else {
            next.hint = nil
        }
        return next
    }

    private func changing(_ cell: Int, to change: (Tile) -> Tile) -> GameState {
        var next = self
        next.hint = nil
        if isSolved || puzzle.isGiven(cell) {
            return next
        }
        let from = grid.tiles[cell]
        let to = change(from)
        if to == from {
            return next
        }
        next.grid = grid.with(cell: cell, tile: to)
        next.changes.append(Change(cell: cell, from: from, to: to))
        return next
    }
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
