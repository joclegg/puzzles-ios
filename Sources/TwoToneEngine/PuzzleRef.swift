import PuzzlesCore

public enum GameStatus: String, Sendable, CaseIterable {
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

public struct PuzzleRef: Sendable, Equatable {
    public static let dailyPrefix = "daily_"

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
        PuzzleRef.isDaily(id: id)
    }

    public var slot: String {
        PuzzleRef.slot(id: id, size: size)
    }

    public var title: String {
        PuzzleRef.title(id: id, size: size)
    }

    public static func isDaily(id: String) -> Bool {
        id.hasPrefix(dailyPrefix)
    }

    public static func slot(id: String, size: Int) -> String {
        isDaily(id: id) ? id : "size_\(size)"
    }

    public static func title(id: String, size: Int) -> String {
        guard isDaily(id: id) else {
            return sizeLabel(size)
        }
        let date = id.dropFirst(dailyPrefix.count).prefix { $0 != "_" }
        return "Daily · \(dayMonth(isoDate: String(date))) · \(sizeLabel(size))"
    }

    public static func random(seed: Int64, size: Int) -> PuzzleRef {
        PuzzleRef(id: "random_\(seed)", puzzle: Generator.generate(size: size, seed: seed))
    }

    public static func dailyId(date: CalendarDay, size: Int) -> String {
        "\(dailyPrefix)\(date.isoString)_\(size)"
    }

    public static func daily(date: CalendarDay, size: Int) -> PuzzleRef {
        PuzzleRef(id: dailyId(date: date, size: size), puzzle: Generator.daily(date: date, size: size))
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

    public static func of(size: Int, games: [(size: Int, status: GameStatus, elapsedMs: Int64)]) -> SizeStats {
        let finished = games.filter { $0.size == size && $0.status != .inProgress }
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

public struct BoardMarks: Sendable, Equatable {
    public let givens: Set<Int>
    public let broken: Set<Int>
    public let hintLine: Set<Int>
    public let hintTargets: Set<Int>
    public let hintTwin: Set<Int>
}

extension GameState {
    public func boardMarks(markBrokenRules: Bool) -> BoardMarks {
        var line = Set<Int>()
        var targets = Set<Int>()
        var twin = Set<Int>()
        switch hint {
        case .mistake(let cells):
            targets = Set(cells)
        case .next(let deduction, let cells):
            line = Set(cells)
            targets = Set(deduction.cells)
            if let twinLine = deduction.twin {
                twin = Set(grid.cellsOf(twinLine))
            }
        case nil:
            break
        }
        return BoardMarks(
            givens: Set(grid.tiles.indices.filter(puzzle.isGiven)),
            broken: markBrokenRules ? brokenCells : [],
            hintLine: line,
            hintTargets: targets,
            hintTwin: twin
        )
    }
}

extension Hint {
    public var message: String {
        switch self {
        case .mistake(let cells):
            return cells.count == 1 ? "This tile is the wrong colour." : "These \(cells.count) tiles are the wrong colour."
        case .next(let deduction, _):
            let line = deduction.line.isRow ? "row" : "column"
            switch deduction.reason {
            case .pair:
                return "Two tiles of the same colour sit side by side in this \(line), so the tile next to them is the other colour."
            case .gap:
                return "A gap between two tiles of the same colour in this \(line) must be the other colour."
            case .balance:
                return "This \(line) already has half its tiles in one colour, so the rest are the other colour."
            case .unique:
                return "Filling this \(line) one way would copy another \(line), so it goes the other way."
            }
        }
    }
}

public func sizeLabel(_ size: Int) -> String {
    "\(size) x \(size)"
}

public func formatDuration(_ ms: Int64) -> String {
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

public func dayMonth(isoDate: String) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    let parts = isoDate.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]), months.indices.contains(month - 1) else {
        return isoDate
    }
    return "\(day) \(months[month - 1])"
}
