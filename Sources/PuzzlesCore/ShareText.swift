public let shareLinkLine = "joclegg.github.io/puzzles-web"

public struct DailyShareEntry: Sendable, Equatable {
    public let label: String
    public let timeMs: Int64?
    public let bestMs: Int64?
    public let moves: Int?

    public init(label: String, timeMs: Int64?, bestMs: Int64? = nil, moves: Int? = nil) {
        self.label = label
        self.timeMs = timeMs
        self.bestMs = bestMs
        self.moves = moves
    }
}

public struct DailyStreak: Sendable, Equatable {
    public let current: Int
    public let longest: Int

    public init(current: Int, longest: Int) {
        self.current = current
        self.longest = longest
    }
}

public func medalEmoji(_ medal: Medal) -> String {
    switch medal {
    case .gold:
        "🥇"
    case .silver:
        "🥈"
    case .bronze:
        "🥉"
    case .none:
        ""
    }
}

public func medalSquare(_ medal: Medal) -> String {
    switch medal {
    case .gold:
        "🟨"
    case .silver:
        "⬜"
    case .bronze:
        "🟧"
    case .none:
        "⬛"
    }
}

public func dailyShareLine(_ entry: DailyShareEntry) -> String {
    guard let time = entry.timeMs else {
        return "\(entry.label) ⬛"
    }
    var line = "\(entry.label) \(formatDuration(time))"
    if let moves = entry.moves {
        line += " · \(moves) moves"
    }
    if let best = entry.bestMs, best == time {
        line += " ⭐"
    }
    return line
}

public func solitaireDailyLine(wonMs: Int64?) -> String {
    wonMs.map { "Won in \(formatDuration($0))" } ?? "Not won"
}

public func fiveLettersDailiesBody(puzzles: String, daily2: String?) -> [String] {
    guard let daily2 else {
        return [puzzles]
    }
    return [puzzles, "", daily2]
}

public func lastSevenMedals(_ days: [CalendarDay: Medal], ending date: CalendarDay) -> [Medal] {
    (0..<7).map { days[date.adding(days: $0 - 6)] ?? .none }
}

public func dailiesShareText(game: String, date: CalendarDay, medal: Medal, body: [String], lastSeven: [Medal])
    -> String
{
    let emoji = medalEmoji(medal)
    let title = "\(game) · \(dayMonthLabel(iso: date.isoString))" + (emoji.isEmpty ? "" : " \(emoji)")
    let squares = lastSeven.map(medalSquare).joined()
    return ([title] + body + ["", "Last 7 days \(squares)", shareLinkLine]).joined(separator: "\n")
}

public func recordLine(label: String, bestMs: Int64, fewestMoves: Int? = nil) -> String {
    let line = "\(label) \(formatDuration(bestMs))"
    return fewestMoves.map { "\(line) · \($0) moves" } ?? line
}

public func solitaireRecordLines(fastestMs: Int64?, fewestMoves: Int?) -> [String] {
    [fastestMs.map { "Fastest win \(formatDuration($0))" }, fewestMoves.map { "Fewest moves \($0)" }].compactMap { $0 }
}

public func guessChartLines(counts: [Int]) -> [String] {
    let largest = counts.max() ?? 0
    return counts.enumerated().map { index, count in
        let squares = count == 0 || largest == 0 ? 0 : max(1, Int((Double(count) * 8 / Double(largest)).rounded()))
        return "\(index + 1) \(String(repeating: "🟩", count: squares)) \(count)"
    }
}

public func streakSummary(_ streak: DailyStreak) -> String {
    "🔥 \(streak.current) · longest 🔥 \(streak.longest)"
}

public func solvedSummary(count: Int, noun: String = "solved", streak: DailyStreak) -> String {
    "\(count) \(noun) · \(streakSummary(streak))"
}

public func solitaireSummary(wins: Int, played: Int, streak: DailyStreak) -> String {
    let percent = played == 0 ? 0 : wins * 100 / played
    return "\(wins) wins · \(percent)% · \(streakSummary(streak))"
}

public func fiveLettersSummary(won: Int, played: Int, streak: DailyStreak) -> String {
    "\(won)/\(played) won · \(streakSummary(streak))"
}

public func recordsShareText(game: String, lines: [String], summary: String) -> String {
    (["\(game) records 🏆"] + lines + ["", summary, shareLinkLine]).joined(separator: "\n")
}

public func dailyStreak(days: Set<CalendarDay>, today: CalendarDay) -> DailyStreak {
    var current = 0
    var day = days.contains(today) ? today : today.adding(days: -1)
    while days.contains(day) {
        current += 1
        day = day.adding(days: -1)
    }
    var longest = 0
    var run = 0
    var previous: CalendarDay?
    for day in days.sorted() {
        run = previous.map { day.days(since: $0) == 1 } == true ? run + 1 : 1
        longest = max(longest, run)
        previous = day
    }
    return DailyStreak(current: current, longest: longest)
}
