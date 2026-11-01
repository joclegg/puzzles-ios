import PuzzlesCore

public enum GameStatus: String, Sendable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case solved = "SOLVED"
    case abandoned = "ABANDONED"
    case revealed = "REVEALED"
}

public struct PuzzleRef: Sendable, Equatable {
    public static let dailyPrefix = "daily_"
    private static let firstDay = CalendarDay(year: 2026, month: 10, day: 25)

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
        id.hasPrefix(Self.dailyPrefix)
    }

    public var slot: String {
        isDaily ? id : "size_\(size)"
    }

    public var title: String {
        guard isDaily else {
            return sizeLabel(size)
        }
        let date = id.dropFirst(Self.dailyPrefix.count).prefix { $0 != "_" }
        return "Daily · \(dayMonthLabel(iso: String(date))) · \(sizeLabel(size))"
    }

    public static func random(puzzles: [Puzzle], size: Int, seed: Int64) -> PuzzleRef {
        var random = XorWowRandom(seed: seed)
        let index = random.nextInt(below: puzzles.count)
        return PuzzleRef(id: "bank_\(size)_\(index)", puzzle: puzzles[index])
    }

    public static func dailyId(date: CalendarDay, size: Int) -> String {
        "\(dailyPrefix)\(date.isoString)_\(size)"
    }

    public static func daily(puzzles: [Puzzle], date: CalendarDay, size: Int) -> PuzzleRef {
        var random = XorWowRandom(seed: Int64(size))
        let order = Array(puzzles.indices).shuffled(using: &random)
        let day = date.days(since: firstDay)
        let index = ((day % puzzles.count) + puzzles.count) % puzzles.count
        return PuzzleRef(id: dailyId(date: date, size: size), puzzle: puzzles[order[index]])
    }
}

public struct SavedGame: Sendable, Equatable {
    public var id: Int64
    public var ref: PuzzleRef
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

public struct CombinationDigit: Sendable, Equatable {
    public let digit: Int
    public let placed: Bool

    public init(digit: Int, placed: Bool) {
        self.digit = digit
        self.placed = placed
    }
}

public enum CombinationOrder: String, Sendable, CaseIterable {
    case increasing
    case decreasing
}

public struct CombinationLine: Sendable, Equatable {
    public let header: String
    public let sets: [[CombinationDigit]]

    public init(header: String, sets: [[CombinationDigit]]) {
        self.header = header
        self.sets = sets
    }
}

extension GameState {
    public func combinationLines(order: CombinationOrder = .increasing) -> [CombinationLine] {
        selectedCombinations().map { run, masks in
            let placed = Set(run.cells.map { values[$0] }.filter { $0 != 0 })
            let direction = run.isAcross ? "Across" : "Down"
            return CombinationLine(
                header: "\(direction) \(run.sum) in \(run.cells.count): ",
                sets: Self.ordered(
                    masks.map { mask in
                        Combinations.digitsOf(mask).map { CombinationDigit(digit: $0, placed: placed.contains($0)) }
                    },
                    order
                )
            )
        }
    }

    private static func ordered(_ sets: [[CombinationDigit]], _ order: CombinationOrder) -> [[CombinationDigit]] {
        switch order {
        case .increasing:
            sets
        case .decreasing:
            sets.map { Array($0.reversed()) }.reversed()
        }
    }

    public var doneDigits: Set<Int> {
        Set((1...maxDigit).filter(isDigitDone))
    }

    public var highlightedRunCells: Set<Int> {
        guard let selected else {
            return []
        }
        return Set((puzzle.runsOf[selected] ?? []).flatMap(\.cells))
    }

    public var sameDigitCells: Set<Int> {
        guard let activeDigit else {
            return []
        }
        return Set(values.indices.filter { values[$0] == activeDigit })
    }
}

public func sizeLabel(_ size: Int) -> String {
    "\(size) x \(size)"
}

public func dayMonthLabel(iso: String) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let parts = iso.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]), months.indices.contains(month - 1) else {
        return iso
    }
    return "\(day) \(months[month - 1])"
}
