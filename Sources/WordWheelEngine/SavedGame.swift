import PuzzlesCore

public enum GameStatus: String, Sendable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case solved = "SOLVED"
    case abandoned = "ABANDONED"
    case revealed = "REVEALED"

    public var label: String {
        switch self {
        case .solved:
            "Solved"
        case .inProgress:
            "In progress"
        case .abandoned:
            "Abandoned"
        case .revealed:
            "Solution shown"
        }
    }
}

public struct PuzzleRef: Hashable, Sendable {
    public static let dailyPrefix = "daily_"
    private static let firstDay = CalendarDay(year: 2026, month: 10, day: 25)

    public var id: String
    public var level: Level
    public var puzzle: Puzzle

    public init(id: String, level: Level, puzzle: Puzzle) {
        self.id = id
        self.level = level
        self.puzzle = puzzle
    }

    public var isDaily: Bool {
        id.hasPrefix(Self.dailyPrefix)
    }

    public var slot: String {
        isDaily ? id : level.name
    }

    public var title: String {
        guard isDaily else {
            return level.label
        }
        let iso = id.dropFirst(Self.dailyPrefix.count).prefix { $0 != "_" }
        return "Daily · \(dayLabel(iso: String(iso))) · \(level.label)"
    }

    public static func random(puzzles: [Puzzle], level: Level, seed: Int64) -> PuzzleRef {
        var random = XorWowRandom(seed: seed)
        let index = random.nextInt(below: puzzles.count)
        return PuzzleRef(id: "bank_\(level.name)_\(index)", level: level, puzzle: puzzles[index])
    }

    public static func dailyId(date: CalendarDay, level: Level) -> String {
        "\(dailyPrefix)\(date.isoString)_\(level.name.lowercased())"
    }

    public static func daily(puzzles: [Puzzle], date: CalendarDay, level: Level) -> PuzzleRef {
        var random = XorWowRandom(seed: Int64(level.rawValue))
        let order = Array(puzzles.indices).shuffled(using: &random)
        let day = date.days(since: firstDay)
        let index = ((day % puzzles.count) + puzzles.count) % puzzles.count
        return PuzzleRef(id: dailyId(date: date, level: level), level: level, puzzle: puzzles[order[index]])
    }
}

public struct SavedGame: Hashable, Sendable, Identifiable {
    public var id: Int64
    public var ref: PuzzleRef
    public var found: [String]
    public var bonus: [String]
    public var revealed: [Cell]
    public var elapsedMs: Int64
    public var status: GameStatus
    public var startedAt: Int64
    public var finishedAt: Int64?

    public init(
        id: Int64,
        ref: PuzzleRef,
        found: [String] = [],
        bonus: [String] = [],
        revealed: [Cell] = [],
        elapsedMs: Int64 = 0,
        status: GameStatus = .inProgress,
        startedAt: Int64,
        finishedAt: Int64? = nil
    ) {
        self.id = id
        self.ref = ref
        self.found = found
        self.bonus = bonus
        self.revealed = revealed
        self.elapsedMs = elapsedMs
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct LevelStats: Hashable, Sendable {
    public var level: Level
    public var played: Int
    public var solved: Int
    public var bonusWords: Int
    public var bestMs: Int64?

    public static func of(_ games: [SavedGame], level: Level) -> LevelStats {
        let finished = games.filter { $0.ref.level == level && $0.status != .inProgress }
        let solved = finished.filter { $0.status == .solved }
        return LevelStats(
            level: level,
            played: finished.count,
            solved: solved.count,
            bonusWords: finished.reduce(0) { $0 + $1.bonus.count },
            bestMs: solved.map(\.elapsedMs).min()
        )
    }
}

public enum SavedGameCodec {
    public static func encodeWords(_ words: [String]) -> String {
        words.joined(separator: ",")
    }

    public static func decodeWords(_ text: String) -> [String] {
        text.split(separator: ",").map(String.init)
    }

    public static func encodeCells(_ cells: [Cell]) -> String {
        cells.map { "\($0.row):\($0.col)" }.joined(separator: ",")
    }

    public static func decodeCells(_ text: String) throws -> [Cell] {
        try text.split(separator: ",").map { item in
            let parts = item.split(separator: ":")
            guard parts.count == 2, let row = Int(parts[0]), let col = Int(parts[1]) else {
                throw DecodeError.malformed(text)
            }
            return Cell(row: row, col: col)
        }
    }
}

extension Level {
    public var label: String {
        "\(letters) letters"
    }
}

extension Guess {
    public var message: String {
        switch self {
        case .found:
            "Nice!"
        case .bonus:
            "Bonus word!"
        case .already:
            "Already found"
        case .notAWord:
            "Not a word"
        case .tooShort:
            "Three letters or more"
        }
    }
}

public func dayLabel(iso: String) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let parts = iso.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]), months.indices.contains(month - 1)
    else {
        return iso
    }
    return "\(day) \(months[month - 1])"
}
