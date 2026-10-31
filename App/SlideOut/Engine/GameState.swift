public enum SlideOutMoveCodec {
    public static func encode(_ moves: [SlideOutMove]) -> String {
        moves.map { "\($0.block):\($0.position)" }.joined(separator: ",")
    }

    public static func decode(_ text: String) throws -> [SlideOutMove] {
        try text.split(separator: ",").map { code in
            let numbers = try code.split(separator: ":", omittingEmptySubsequences: false).map { part in
                guard let number = Int(part) else {
                    throw SlideOutDecodeError.malformed(text)
                }
                return number
            }
            guard numbers.count >= 2 else {
                throw SlideOutDecodeError.malformed(text)
            }
            return SlideOutMove(block: numbers[0], position: numbers[1])
        }
    }
}

public struct SlideOutGameState: Sendable, Equatable {
    public let puzzle: SlideOutPuzzle
    public let moves: [SlideOutMove]
    public let hint: SlideOutMove?
    public let board: SlideOutBoard

    public init(puzzle: SlideOutPuzzle, moves: [SlideOutMove] = [], hint: SlideOutMove? = nil) {
        self.puzzle = puzzle
        self.moves = moves
        self.hint = hint
        board = moves.reduce(puzzle.board) { $0.move($1.block, to: $1.position) }
    }

    public var isSolved: Bool {
        board.isSolved
    }

    public func slide(_ block: Int, to position: Int) -> SlideOutGameState {
        if isSolved || position == board.blocks[block].position || !board.range(block).contains(position) {
            return SlideOutGameState(puzzle: puzzle, moves: moves)
        }
        let move = SlideOutMove(block: block, position: position)
        let merged = moves.last?.block == block ? moves.dropLast() + [move] : moves + [move]
        let isBack = position == previousPosition(block, in: merged)
        return SlideOutGameState(puzzle: puzzle, moves: isBack ? Array(merged.dropLast()) : merged)
    }

    public func undo() -> SlideOutGameState {
        if isSolved || moves.isEmpty {
            return SlideOutGameState(puzzle: puzzle, moves: moves)
        }
        return SlideOutGameState(puzzle: puzzle, moves: Array(moves.dropLast()))
    }

    public func restart() -> SlideOutGameState {
        SlideOutGameState(puzzle: puzzle)
    }

    public func revealSolution() -> SlideOutGameState {
        SlideOutGameState(puzzle: puzzle, moves: moves + (SlideOutSolver.shortest(board) ?? []))
    }

    public func withHint() -> SlideOutGameState {
        if isSolved {
            return self
        }
        return SlideOutGameState(puzzle: puzzle, moves: moves, hint: SlideOutSolver.shortest(board)?.first)
    }

    private func previousPosition(_ block: Int, in moves: [SlideOutMove]) -> Int {
        moves.dropLast().last { $0.block == block }?.position ?? puzzle.board.blocks[block].position
    }
}

public struct SlideOutGameTimer: Sendable, Equatable {
    public var accumulatedMs: Int64
    public var runningSinceMs: Int64?

    public init(accumulatedMs: Int64 = 0, runningSinceMs: Int64? = nil) {
        self.accumulatedMs = accumulatedMs
        self.runningSinceMs = runningSinceMs
    }

    public func start(nowMs: Int64) -> SlideOutGameTimer {
        if runningSinceMs != nil {
            return self
        }
        return SlideOutGameTimer(accumulatedMs: accumulatedMs, runningSinceMs: nowMs)
    }

    public func pause(nowMs: Int64) -> SlideOutGameTimer {
        guard let runningSinceMs else {
            return self
        }
        return SlideOutGameTimer(accumulatedMs: accumulatedMs + (nowMs - runningSinceMs))
    }

    public func elapsedMs(nowMs: Int64) -> Int64 {
        accumulatedMs + (runningSinceMs.map { nowMs - $0 } ?? 0)
    }
}
