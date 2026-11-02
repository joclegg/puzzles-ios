import PuzzlesCore

public enum MoveCodec {
    public static func encode(_ moves: [Move]) -> String {
        moves.map { "\($0.block):\($0.position)" }.joined(separator: ",")
    }

    public static func decode(_ text: String) throws -> [Move] {
        try text.split(separator: ",").map { code in
            let numbers = try code.split(separator: ":", omittingEmptySubsequences: false).map { part in
                guard let number = Int(part) else {
                    throw DecodeError.malformed(text)
                }
                return number
            }
            guard numbers.count >= 2 else {
                throw DecodeError.malformed(text)
            }
            return Move(block: numbers[0], position: numbers[1])
        }
    }
}

public struct GameState: Sendable, Equatable {
    public let puzzle: Puzzle
    public let moves: [Move]
    public let hint: Move?
    public let board: Board

    public init(puzzle: Puzzle, moves: [Move] = [], hint: Move? = nil) {
        self.puzzle = puzzle
        self.moves = moves
        self.hint = hint
        board = moves.reduce(puzzle.board) { $0.move($1.block, to: $1.position) }
    }

    public var isSolved: Bool {
        board.isSolved
    }

    public func slide(_ block: Int, to position: Int) -> GameState {
        if isSolved || position == board.blocks[block].position || !board.range(block).contains(position) {
            return GameState(puzzle: puzzle, moves: moves)
        }
        let move = Move(block: block, position: position)
        let merged = moves.last?.block == block ? moves.dropLast() + [move] : moves + [move]
        let isBack = position == previousPosition(block, in: merged)
        return GameState(puzzle: puzzle, moves: isBack ? Array(merged.dropLast()) : merged)
    }

    public func undo() -> GameState {
        if isSolved || moves.isEmpty {
            return GameState(puzzle: puzzle, moves: moves)
        }
        return GameState(puzzle: puzzle, moves: Array(moves.dropLast()))
    }

    public func restart() -> GameState {
        GameState(puzzle: puzzle)
    }

    public func revealSolution() -> GameState {
        GameState(puzzle: puzzle, moves: moves + (Solver.shortest(board) ?? []))
    }

    public func withHint() -> GameState {
        if isSolved {
            return self
        }
        return GameState(puzzle: puzzle, moves: moves, hint: Solver.shortest(board)?.first)
    }

    private func previousPosition(_ block: Int, in moves: [Move]) -> Int {
        moves.dropLast().last { $0.block == block }?.position ?? puzzle.board.blocks[block].position
    }
}
