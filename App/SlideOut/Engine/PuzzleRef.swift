import PuzzlesCore

public enum SlideOutGameStatus: String, CaseIterable, Sendable {
    case inProgress = "IN_PROGRESS"
    case solved = "SOLVED"
    case abandoned = "ABANDONED"
    case revealed = "REVEALED"

    public var label: String {
        switch self {
        case .inProgress:
            "In progress"
        case .solved:
            "Solved"
        case .abandoned:
            "Abandoned"
        case .revealed:
            "Solution shown"
        }
    }
}

public struct SlideOutPuzzleRef: Hashable, Sendable {
    public static let dailyPrefix = "daily_"
    private static let firstDay = CalendarDay(year: 2026, month: 10, day: 25)

    public let id: String
    public let level: SlideOutLevel
    public let puzzle: SlideOutPuzzle

    public init(id: String, level: SlideOutLevel, puzzle: SlideOutPuzzle) {
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
        let date = id.dropFirst(Self.dailyPrefix.count).prefix { $0 != "_" }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return level.label
        }
        return "Daily · \(SlideOutDayMonthLabel(month: parts[1], day: parts[2])) · \(level.label)"
    }

    public static func random(puzzles: [SlideOutPuzzle], level: SlideOutLevel, seed: Int64) -> SlideOutPuzzleRef {
        var random = XorWowRandom(seed: seed)
        let index = random.nextInt(below: puzzles.count)
        return SlideOutPuzzleRef(id: "bank_\(level.name)_\(index)", level: level, puzzle: puzzles[index])
    }

    public static func dailyId(date: CalendarDay, level: SlideOutLevel) -> String {
        "\(dailyPrefix)\(date.isoString)_\(level.name.lowercased())"
    }

    public static func daily(puzzles: [SlideOutPuzzle], date: CalendarDay, level: SlideOutLevel) -> SlideOutPuzzleRef {
        var random = XorWowRandom(seed: Int64(level.rawValue))
        let order = Array(puzzles.indices).shuffled(using: &random)
        let day = date.days(since: firstDay)
        let wrapped = ((day % puzzles.count) + puzzles.count) % puzzles.count
        return SlideOutPuzzleRef(id: dailyId(date: date, level: level), level: level, puzzle: puzzles[order[wrapped]])
    }
}

public struct SlideOutFinishedGame: Sendable {
    public let level: SlideOutLevel
    public let status: SlideOutGameStatus
    public let moveCount: Int
    public let par: Int
    public let elapsedMs: Int64

    public init(level: SlideOutLevel, status: SlideOutGameStatus, moveCount: Int, par: Int, elapsedMs: Int64) {
        self.level = level
        self.status = status
        self.moveCount = moveCount
        self.par = par
        self.elapsedMs = elapsedMs
    }
}

public struct SlideOutLevelStats: Equatable, Sendable {
    public let level: SlideOutLevel
    public let played: Int
    public let solved: Int
    public let atPar: Int
    public let bestMs: Int64?

    public static func of(_ games: [SlideOutFinishedGame]) -> [SlideOutLevelStats] {
        SlideOutLevel.allCases.map { level in
            let finished = games.filter { $0.level == level && $0.status != .inProgress }
            let solved = finished.filter { $0.status == .solved }
            return SlideOutLevelStats(
                level: level,
                played: finished.count,
                solved: solved.count,
                atPar: solved.count { $0.moveCount <= $0.par },
                bestMs: solved.map(\.elapsedMs).min()
            )
        }
    }
}

extension SlideOutLevel {
    public var label: String {
        name.prefix(1) + name.dropFirst().lowercased()
    }
}

public func SlideOutSolvedMovesText(moveCount: Int, par: Int) -> String {
    moveCount <= par ? "\(moveCount) moves, par!" : "\(moveCount) moves, par is \(par)"
}

public func SlideOutIsNewBest(elapsedMs: Int64, previousBestMs: Int64?) -> Bool {
    previousBestMs.map { elapsedMs < $0 } ?? true
}

public func SlideOutFormatDuration(_ ms: Int64) -> String {
    let total = ms / 1000
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let seconds = total % 60
    let paddedSeconds = seconds < 10 ? "0\(seconds)" : "\(seconds)"
    if hours > 0 {
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hours):\(paddedMinutes):\(paddedSeconds)"
    }
    return "\(minutes):\(paddedSeconds)"
}

public func SlideOutDayMonthLabel(month: Int, day: Int) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return "\(day) \(months[month - 1])"
}
