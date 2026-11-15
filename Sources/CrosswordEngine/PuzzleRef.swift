import PuzzlesCore

public typealias GameStatus = PuzzleStatus

public let dailyPoolSize = 3000

public struct PuzzleRef: Sendable, Equatable {
    public static let dailyPrefix = DailyId.prefix
    private static let firstDay = CalendarDay(year: 2026, month: 11, day: 16)

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
            return sizeName(size)
        }
        let date = DailyId.isoDate(of: id)
        return "Daily · \(dayMonthLabel(iso: String(date))) · \(sizeName(size))"
    }

    public static func random(puzzles: [Puzzle], size: Int, seed: Int64) -> PuzzleRef {
        var random = XorWowRandom(seed: seed)
        let index = random.nextInt(below: puzzles.count)
        return PuzzleRef(id: "bank_\(size)_\(index)", puzzle: puzzles[index])
    }

    public static func dailyId(date: CalendarDay, size: Int) -> String {
        DailyId.make(date: date, suffix: "\(size)")
    }

    public static func dailyIndex(count: Int, date: CalendarDay, size: Int) -> Int {
        let pool = min(count, dailyPoolSize)
        var random = XorWowRandom(seed: Int64(size))
        let order = Array(0..<pool).shuffled(using: &random)
        let day = date.days(since: firstDay)
        return order[((day % pool) + pool) % pool]
    }

    public static func daily(puzzles: [Puzzle], date: CalendarDay, size: Int) -> PuzzleRef {
        PuzzleRef(
            id: dailyId(date: date, size: size),
            puzzle: puzzles[dailyIndex(count: puzzles.count, date: date, size: size)]
        )
    }
}

public struct SavedGame: Sendable, Equatable {
    public var id: Int64
    public var ref: PuzzleRef
    public var entries: [Character]
    public var changes: [Change]
    public var elapsedMs: Int64
    public var hints: Int
    public var mistakes: Int
    public var status: GameStatus
    public var startedAt: Int64
    public var finishedAt: Int64?

    public init(
        id: Int64,
        ref: PuzzleRef,
        entries: [Character]? = nil,
        changes: [Change] = [],
        elapsedMs: Int64 = 0,
        hints: Int = 0,
        mistakes: Int = 0,
        status: GameStatus = .inProgress,
        startedAt: Int64,
        finishedAt: Int64? = nil
    ) {
        self.id = id
        self.ref = ref
        self.entries = entries ?? GameState.emptyEntries(ref.puzzle)
        self.changes = changes
        self.elapsedMs = elapsedMs
        self.hints = hints
        self.mistakes = mistakes
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

    public static func of(size: Int, games: [SavedGame]) -> SizeStats {
        let finished = games.filter { $0.ref.size == size && $0.status != .inProgress }
        let times = finished.filter { $0.status == .solved }.map(\.elapsedMs)
        return SizeStats(
            size: size,
            played: finished.count,
            solved: times.count,
            bestMs: times.min(),
            averageMs: times.isEmpty ? nil : times.reduce(0, +) / Int64(times.count)
        )
    }
}
