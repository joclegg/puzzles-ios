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
