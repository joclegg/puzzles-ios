import PuzzlesCore

public enum GameStatus: String, Sendable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case won = "WON"
    case lost = "LOST"
    case abandoned = "ABANDONED"

    public var homeLabel: String? {
        switch self {
        case .won:
            "Solved"
        case .lost:
            "Missed today"
        case .inProgress:
            "In progress"
        case .abandoned:
            nil
        }
    }
}

public struct WordRef: Hashable, Sendable {
    public static let dailyPrefix = "daily_"
    public static let daily2Prefix = "daily2_"
    private static let practiceSlot = "practice"

    public let id: String
    public let answer: String

    public init(id: String, answer: String) {
        self.id = id
        self.answer = answer
    }

    public var isDaily: Bool {
        id.hasPrefix(WordRef.dailyPrefix)
    }

    public var isDaily2: Bool {
        daily2Date != nil
    }

    private var daily2Date: CalendarDay? {
        guard let prefix = [WordRef.daily2Prefix, legacyDaily2Prefix].first(where: id.hasPrefix) else {
            return nil
        }
        return CalendarDay(iso: String(id.dropFirst(prefix.count)))
    }

    public var slot: String {
        isDaily || isDaily2 ? id : WordRef.practiceSlot
    }

    public var title: String {
        if isDaily, let date = CalendarDay(iso: String(id.dropFirst(WordRef.dailyPrefix.count))) {
            return "Five Letters \(Words.dayNumber(date))"
        }
        if let date = daily2Date {
            return "Daily puzzle 2 · \(Words.dayNumber(date))"
        }
        return "Practice"
    }

    public static func dailyId(_ date: CalendarDay) -> String {
        dailyPrefix + date.isoString
    }

    public static func daily2Id(_ date: CalendarDay) -> String {
        daily2Prefix + date.isoString
    }

    public static func daily(words: Words, date: CalendarDay) -> WordRef {
        WordRef(id: dailyId(date), answer: words.daily(date))
    }

    public static func daily2(date: CalendarDay, answer: String) -> WordRef {
        WordRef(id: daily2Id(date), answer: answer)
    }

    public static func practice(words: Words, seed: Int64) -> WordRef {
        WordRef(id: "practice_\(seed)", answer: words.random(seed: seed))
    }
}

public struct SavedGame: Hashable, Sendable {
    public let uuid: String
    public let ref: WordRef
    public var guesses: [String]
    public let hardMode: Bool
    public var status: GameStatus
    public let startedAt: Int64
    public var finishedAt: Int64?

    public init(
        uuid: String,
        ref: WordRef,
        guesses: [String] = [],
        hardMode: Bool = false,
        status: GameStatus = .inProgress,
        startedAt: Int64 = 0,
        finishedAt: Int64? = nil
    ) {
        self.uuid = uuid
        self.ref = ref
        self.guesses = guesses
        self.hardMode = hardMode
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var gameState: GameState {
        GameState(
            answer: ref.answer,
            guesses: guesses,
            hardMode: hardMode,
            revealed: status == .lost && guesses.count < maxGuesses
        )
    }
}

public struct WordStats: Equatable, Sendable {
    public let played: Int
    public let won: Int
    public let currentStreak: Int
    public let maxStreak: Int
    public let guessCounts: [Int]

    public init(history: [SavedGame]) {
        let finished = history.filter { $0.status == .won || $0.status == .lost }
            .sorted { ($0.finishedAt ?? 0) < ($1.finishedAt ?? 0) }
        var streak = 0
        var best = 0
        for game in finished {
            streak = game.status == .won ? streak + 1 : 0
            best = max(best, streak)
        }
        played = finished.count
        won = finished.count { $0.status == .won }
        currentStreak = streak
        maxStreak = best
        guessCounts = (1...maxGuesses).map { count in
            finished.count { $0.status == .won && $0.guesses.count == count }
        }
    }

    public var winPercent: Int {
        played == 0 ? 0 : won * 100 / played
    }

    public func barFraction(guesses: Int) -> Double {
        let minimum = 0.08
        let most = max(guessCounts.max() ?? 0, 1)
        return minimum + (1 - minimum) * Double(guessCounts[guesses - 1]) / Double(most)
    }
}

public func encodeGuesses(_ guesses: [String]) -> String {
    guesses.joined(separator: ",")
}

public func decodeGuesses(_ text: String) -> [String] {
    text.split(separator: ",").map(String.init)
}

public func daily2Word(json: String) -> String? {
    guard let match = json.firstMatch(of: /"word"\s*:\s*"([A-Za-z]+)"/) else {
        return nil
    }
    let word = match.1.uppercased()
    return word.count == wordLength ? word : nil
}

extension Rejection {
    public var message: String {
        switch self {
        case .tooShort:
            "Not enough letters"
        case .notAWord:
            "Not in the word list"
        case .mustUseHints:
            "Hard mode: use every hint you've found"
        }
    }
}

extension GameState {
    public var hintMessage: String? {
        hintLetter().map { "Letter \($0.index + 1) is \($0.letter)." }
    }

    public var resultTitle: String {
        isWon ? "Got it in \(guesses.count)!" : "The word was \(answer)"
    }
}

extension CalendarDay {
    public init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            return nil
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}
