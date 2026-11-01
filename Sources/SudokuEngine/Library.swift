import PuzzlesCore

public enum GameMode: String, Sendable, CaseIterable, Hashable {
    case classic = "CLASSIC"
    case killer = "KILLER"

    public var levels: [Difficulty] {
        self == .killer ? killerLevels : classicLevels
    }

    public var label: String {
        self == .killer ? "Killer" : "Classic"
    }

    public var slug: String {
        rawValue.lowercased()
    }

    var ordinal: Int64 {
        self == .killer ? 1 : 0
    }
}

public enum GameStatus: String, Sendable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case abandoned = "ABANDONED"
    case revealed = "REVEALED"

    public var label: String {
        switch self {
        case .completed:
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

public struct PuzzleRef: Sendable, Equatable {
    public static let dailyPrefix = "daily_"

    public var id: String
    public var mode: GameMode
    public var difficulty: Difficulty?
    public var puzzle: Puzzle
    public var custom: Bool

    public init(id: String, mode: GameMode, difficulty: Difficulty?, puzzle: Puzzle, custom: Bool = false) {
        self.id = id
        self.mode = mode
        self.difficulty = difficulty
        self.puzzle = puzzle
        self.custom = custom
    }

    public var slot: String {
        if custom {
            return "custom"
        }
        if id.hasPrefix(Self.dailyPrefix) {
            return id
        }
        return Self.levelSlot(mode: mode, difficulty: difficulty)
    }

    public static func levelSlot(mode: GameMode, difficulty: Difficulty?) -> String {
        "\(mode.rawValue)_\(difficulty?.name ?? "null")"
    }
}

public enum DailyIds {
    public static func of(mode: GameMode, difficulty: Difficulty, date: CalendarDay) -> String {
        "\(PuzzleRef.dailyPrefix)\(mode.slug)_\(difficulty.name.lowercased()):\(date.isoString)"
    }

    public static func parse(_ id: String) -> (mode: GameMode, date: CalendarDay)? {
        guard id.hasPrefix(PuzzleRef.dailyPrefix) else {
            return nil
        }
        let fields = parts(id.dropFirst(PuzzleRef.dailyPrefix.count), separator: ":")
        guard fields.count == 2, let kind = fields[0].split(separator: "_", omittingEmptySubsequences: false).first,
            let mode = GameMode(rawValue: kind.uppercased()), let date = parseCalendarDay(fields[1])
        else {
            return nil
        }
        return (mode, date)
    }
}

public enum BankPick {
    private static let dailySeedStride: Int64 = 31
    private static let dailyModeStride: Int64 = 8

    public static func fileName(mode: GameMode, difficulty: Difficulty) -> String {
        "\(mode.slug)_\(difficulty.name.lowercased())"
    }

    public static func dailyIndex(mode: GameMode, difficulty: Difficulty, date: CalendarDay, size: Int) -> Int {
        let level = Int64(mode.levels.firstIndex(of: difficulty) ?? -1)
        let seed = Int64(date.daysSinceEpoch) * dailySeedStride + mode.ordinal * dailyModeStride + level
        var random = XorWowRandom(seed: seed)
        return random.nextInt(below: size)
    }
}

public func formatDuration(_ ms: Int64) -> String {
    let total = ms / 1000
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let seconds = total % 60
    let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
    if hours > 0 {
        let minutesText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hours):\(minutesText):\(secondsText)"
    }
    return "\(minutes):\(secondsText)"
}

public func levelLabel(_ difficulty: Difficulty?) -> String {
    guard let difficulty else {
        return "Expert+"
    }
    let name = difficulty.name.lowercased()
    return name.prefix(1).uppercased() + name.dropFirst()
}

public func gameTitle(killer: Bool, custom: Bool, difficulty: Difficulty?, answerKnown: Bool = true) -> String {
    let kind: String
    if custom {
        kind = killer ? "Custom killer" : "Custom"
    } else {
        kind = killer ? "Killer" : "Classic"
    }
    return answerKnown ? "\(kind) · \(levelLabel(difficulty))" : kind
}

public struct BestTime: Sendable, Equatable {
    public let mode: GameMode
    public let difficulty: Difficulty
    public let bestMs: Int64
    public let averageMs: Int64
    public let completed: Int

    public init(mode: GameMode, difficulty: Difficulty, bestMs: Int64, averageMs: Int64, completed: Int) {
        self.mode = mode
        self.difficulty = difficulty
        self.bestMs = bestMs
        self.averageMs = averageMs
        self.completed = completed
    }
}

public struct FinishedGame: Sendable {
    public let mode: GameMode
    public let difficulty: Difficulty
    public let elapsedMs: Int64

    public init(mode: GameMode, difficulty: Difficulty, elapsedMs: Int64) {
        self.mode = mode
        self.difficulty = difficulty
        self.elapsedMs = elapsedMs
    }
}

public func bestTimes(finished: [FinishedGame], past: [FinishedGame]) -> [BestTime] {
    var result: [BestTime] = []
    for mode in GameMode.allCases {
        for difficulty in mode.levels {
            let played = finished.filter { $0.mode == mode && $0.difficulty == difficulty }.map(\.elapsedMs)
            let earlier = past.filter { $0.mode == mode && $0.difficulty == difficulty }.map(\.elapsedMs)
            guard let best = (played + earlier).min() else {
                continue
            }
            let average = played.isEmpty ? 0 : played.reduce(0, +) / Int64(played.count)
            result.append(
                BestTime(mode: mode, difficulty: difficulty, bestMs: best, averageMs: average, completed: played.count))
        }
    }
    return result
}

public enum DigitCounts: String, Sendable, CaseIterable {
    case countUp = "COUNT_UP"
    case countDown = "COUNT_DOWN"
    case off = "OFF"
}

public enum HintStyle: String, Sendable, CaseIterable {
    case point = "POINT"
    case fill = "FILL"
}

public enum ThemeMode: String, Sendable, CaseIterable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"
}

public enum SettingToggle: String, Sendable, CaseIterable {
    case showMistakeCount = "show_mistake_count"
    case highlightHouses = "highlight_houses"
    case highlightCage = "highlight_cage"
    case autoRemoveNotes = "auto_remove_notes"
    case disableCompletedDigits = "disable_completed_digits"
    case showTimer = "show_timer"
    case boldPlacedDigits = "bold_placed_digits"
    case highlightLastPlaced = "highlight_last_placed"
    case greyGivenCells = "grey_given_cells"
    case showHints = "show_hints"
    case showTutorial = "show_tutorial"
    case allowReveal = "allow_reveal"

    public func defaultFor(_ mode: GameMode) -> Bool {
        switch self {
        case .showTimer, .boldPlacedDigits, .showTutorial:
            true
        case .greyGivenCells:
            mode != .killer
        case .showMistakeCount, .highlightHouses, .highlightCage, .autoRemoveNotes, .disableCompletedDigits,
            .highlightLastPlaced, .showHints, .allowReveal:
            false
        }
    }

    public func key(_ mode: GameMode) -> String {
        "sudoku_\(rawValue)_\(mode.slug)"
    }
}

public enum SettingKeys {
    public static let inputMode = "sudoku_input_mode"
    public static let theme = "sudoku_theme"
    public static let customDraft = "sudoku_custom_draft"

    public static func mistakes(_ mode: GameMode) -> String {
        "sudoku_mistakes_\(mode.slug)"
    }

    public static func sameNumber(_ mode: GameMode) -> String {
        "sudoku_highlight_same_number_\(mode.slug)"
    }

    public static func notes(_ mode: GameMode) -> String {
        "sudoku_highlight_notes_\(mode.slug)"
    }

    public static func digitCounts(_ mode: GameMode) -> String {
        "sudoku_digit_counts_\(mode.slug)"
    }

    public static func hintStyle(_ mode: GameMode) -> String {
        "sudoku_hint_style_\(mode.slug)"
    }
}

public struct ModeSettings: Sendable, Equatable {
    public static let defaultMistakeCheck = MistakeCheck.off
    public static let defaultHighlightStyle = HighlightStyle.off
    public static let defaultDigitCounts = DigitCounts.off

    public var mistakeCheck: MistakeCheck = Self.defaultMistakeCheck
    public var sameNumberStyle: HighlightStyle = Self.defaultHighlightStyle
    public var notesStyle: HighlightStyle = Self.defaultHighlightStyle
    public var digitCounts: DigitCounts = Self.defaultDigitCounts
    public var hintStyle: HintStyle = .point
    public var toggles: [SettingToggle: Bool] = [:]

    public init() {}

    public init(mode: GameMode, bool: (String) -> Bool?, string: (String) -> String?) {
        mistakeCheck = string(SettingKeys.mistakes(mode)).flatMap(MistakeCheck.init(rawValue:)) ?? Self.defaultMistakeCheck
        sameNumberStyle = string(SettingKeys.sameNumber(mode)).flatMap(HighlightStyle.init(rawValue:)) ?? Self.defaultHighlightStyle
        notesStyle = string(SettingKeys.notes(mode)).flatMap(HighlightStyle.init(rawValue:)) ?? Self.defaultHighlightStyle
        digitCounts = string(SettingKeys.digitCounts(mode)).flatMap(DigitCounts.init(rawValue:)) ?? Self.defaultDigitCounts
        hintStyle = string(SettingKeys.hintStyle(mode)).flatMap(HintStyle.init(rawValue:)) ?? .point
        for toggle in SettingToggle.allCases {
            toggles[toggle] = bool(toggle.key(mode)) ?? toggle.defaultFor(mode)
        }
    }

    public func isOn(_ toggle: SettingToggle) -> Bool {
        toggles[toggle] ?? toggle.defaultFor(.classic)
    }

    public var playOptions: PlayOptions {
        PlayOptions(
            highlightHouses: isOn(.highlightHouses),
            highlightCage: isOn(.highlightCage),
            sameNumberStyle: sameNumberStyle,
            notesStyle: notesStyle,
            autoRemoveNotes: isOn(.autoRemoveNotes),
            highlightLastPlaced: isOn(.highlightLastPlaced)
        )
    }
}
