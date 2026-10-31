public struct CalendarDay: Hashable, Comparable, Sendable {
    public let daysSinceEpoch: Int

    public init(year: Int, month: Int, day: Int) {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        daysSinceEpoch = era * 146_097 + dayOfEra - 719_468
    }

    public init(daysSinceEpoch: Int) {
        self.daysSinceEpoch = daysSinceEpoch
    }

    public func adding(days: Int) -> CalendarDay {
        CalendarDay(daysSinceEpoch: daysSinceEpoch + days)
    }

    public func days(since other: CalendarDay) -> Int {
        daysSinceEpoch - other.daysSinceEpoch
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.daysSinceEpoch < rhs.daysSinceEpoch
    }
}

extension CalendarDay {
    public var isoString: String {
        let shifted = daysSinceEpoch + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        let monthText = month < 10 ? "0\(month)" : "\(month)"
        let dayText = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(monthText)-\(dayText)"
    }
}
