public enum Medal: String, Sendable, CaseIterable {
    case none
    case bronze
    case silver
    case gold
}

public struct DailyResult: Sendable, Equatable {
    public let date: CalendarDay
    public let id: String
    public let finishedOn: CalendarDay?

    public init(date: CalendarDay, id: String, finishedOn: CalendarDay?) {
        self.date = date
        self.id = id
        self.finishedOn = finishedOn
    }
}

public struct DailyDay: Sendable, Equatable {
    public let date: CalendarDay
    public let medal: Medal
    public let doneLate: Bool

    public init(date: CalendarDay, medal: Medal, doneLate: Bool) {
        self.date = date
        self.medal = medal
        self.doneLate = doneLate
    }
}

public func medalFor(count: Int, total: Int, firstMedal: Medal = .bronze) -> Medal {
    if count == 0 {
        return .none
    }
    if count >= total {
        return .gold
    }
    return count == 1 ? firstMedal : .silver
}

public func dailyDays(results: [DailyResult], total: Int, firstMedal: Medal = .bronze) -> [CalendarDay: DailyDay] {
    Dictionary(grouping: results, by: \.date).reduce(into: [:]) { days, entry in
        let onTheDay = Set(entry.value.filter { $0.finishedOn == entry.key }.map(\.id))
        let medal = medalFor(count: onTheDay.count, total: total, firstMedal: firstMedal)
        days[entry.key] = DailyDay(date: entry.key, medal: medal, doneLate: medal == .none)
    }
}

public func parseCalendarDay(_ text: some StringProtocol) -> CalendarDay? {
    let fields = text.split(separator: "-", omittingEmptySubsequences: false)
    guard fields.count == 3, fields[0].count == 4, fields[1].count == 2, fields[2].count == 2,
        fields.allSatisfy({ $0.allSatisfy(\.isNumber) }),
        let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]),
        (1...12).contains(month), (1...31).contains(day)
    else {
        return nil
    }
    let parsed = CalendarDay(year: year, month: month, day: day)
    return parsed.isoString == text ? parsed : nil
}

public let legacyDaily2Prefix = "nyt_"

public func dailyDate(fromId id: String) -> CalendarDay? {
    guard let prefix = ["daily_", "daily2_", legacyDaily2Prefix].first(where: id.hasPrefix) else {
        return nil
    }
    let rest = id.dropFirst(prefix.count)
    let date = rest.prefix(10)
    let suffix = rest.dropFirst(10)
    guard suffix.isEmpty || suffix.hasPrefix("_") else {
        return nil
    }
    return parseCalendarDay(date)
}
