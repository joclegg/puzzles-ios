import PuzzlesCore

public typealias GameStatus = PuzzleStatus

public struct PuzzleRef: Sendable, Equatable {
    public static let dailyPrefix = DailyId.prefix

    public let id: String
    public let puzzle: Puzzle

    public init(id: String, puzzle: Puzzle) {
        self.id = id
        self.puzzle = puzzle
    }

    public var size: Int {
        puzzle.size
    }

    public var isDaily: Bool {
        DailyId.isDaily(id)
    }

    public var slot: String {
        isDaily ? id : "size_\(size)"
    }

    public var title: String {
        guard isDaily else {
            return sizeLabel(size)
        }
        let iso = DailyId.isoDate(of: id)
        return "Daily · \(dayMonthLabel(iso: String(iso))) · \(sizeLabel(size))"
    }

    public static func random(seed: Int64, size: Int) -> PuzzleRef {
        PuzzleRef(id: "random_\(seed)", puzzle: Generator.generate(size: size, seed: seed))
    }

    public static func dailyId(date: CalendarDay, size: Int) -> String {
        DailyId.make(date: date, suffix: "\(size)")
    }

    public static func daily(date: CalendarDay, size: Int) -> PuzzleRef {
        PuzzleRef(id: dailyId(date: date, size: size), puzzle: Generator.daily(date: date, size: size))
    }
}

public struct SavedGame: Sendable, Equatable, Identifiable {
    public let id: Int64
    public var ref: PuzzleRef
    public var changes: [Change]
    public var elapsedMs: Int64
    public var hints: Int
    public var status: GameStatus
    public var startedAt: Int64
    public var finishedAt: Int64?

    public init(
        id: Int64,
        ref: PuzzleRef,
        changes: [Change] = [],
        elapsedMs: Int64 = 0,
        hints: Int = 0,
        status: GameStatus = .inProgress,
        startedAt: Int64,
        finishedAt: Int64? = nil
    ) {
        self.id = id
        self.ref = ref
        self.changes = changes
        self.elapsedMs = elapsedMs
        self.hints = hints
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct SizeStats: Sendable, Equatable {
    public let size: Int
    public let played: Int
    public let solved: Int
    public let bestMs: Int64?
    public let averageMs: Int64?

    public init(size: Int, played: Int, solved: Int, bestMs: Int64?, averageMs: Int64?) {
        self.size = size
        self.played = played
        self.solved = solved
        self.bestMs = bestMs
        self.averageMs = averageMs
    }
}

extension Array where Element == SavedGame {
    public var inProgress: [SavedGame] {
        filter { $0.status == .inProgress }
    }

    public func savedGame(forSize size: Int) -> SavedGame? {
        first { $0.status == .inProgress && !$0.ref.isDaily && $0.ref.size == size }
    }

    public func dailyInProgress(date: CalendarDay, size: Int) -> SavedGame? {
        let id = PuzzleRef.dailyId(date: date, size: size)
        return first { $0.status == .inProgress && $0.ref.id == id }
    }

    public func dailySolved(date: CalendarDay) -> Set<Int> {
        Set(
            sizes.filter { size in
                let id = PuzzleRef.dailyId(date: date, size: size)
                return contains { $0.ref.id == id && $0.status == .solved }
            }
        )
    }

    public func stats(size: Int) -> SizeStats {
        let finished = filter { $0.ref.size == size && $0.status != .inProgress }
        let solved = finished.filter { $0.status == .solved }.map(\.elapsedMs)
        return SizeStats(
            size: size,
            played: finished.count,
            solved: solved.count,
            bestMs: solved.min(),
            averageMs: solved.isEmpty ? nil : solved.reduce(0, +) / Int64(solved.count)
        )
    }

    public func isNewBest(_ game: SavedGame) -> Bool {
        let others = filter { $0.status == .solved && $0.ref.size == game.ref.size && $0.id != game.id }
        guard let previous = others.map(\.elapsedMs).min() else {
            return true
        }
        return game.elapsedMs < previous
    }
}

extension GameState {
    public var hintSight: Set<Int> {
        if case .next(_, let cells) = hint {
            return Set(cells)
        }
        return []
    }

    public var hintTargets: Set<Int> {
        switch hint {
        case .next(let deduction, _):
            Set(deduction.cells)
        case .mistake(let cells):
            Set(cells)
        case nil:
            []
        }
    }
}

extension Hint {
    public var message: String {
        switch self {
        case .mistake(let cells):
            cells.count == 1 ? "This dot is the wrong colour." : "These \(cells.count) dots are the wrong colour."
        case .next(let deduction, _):
            switch deduction.reason {
            case .satisfied:
                "This number already sees enough blue dots, so the dots that close off its view are red."
            case .tooMany:
                "A blue dot here would let this number see too many, so it is red."
            case .needs:
                "This dot can't see enough the other ways, so this way carries on blue."
            case .alone:
                "A blue dot here would be boxed in and see nothing, so it is red."
            }
        }
    }
}

public func dotTag(cell: Int, size: Int) -> String {
    "dot_r\(cell / size + 1)c\(cell % size + 1)"
}
