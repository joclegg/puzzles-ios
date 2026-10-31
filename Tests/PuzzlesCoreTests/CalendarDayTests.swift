import Testing

@testable import PuzzlesCore

struct CalendarDayTests {
    @Test(
        "given a date when it is converted then the day count is right",
        arguments: [
            (1970, 1, 1, 0),
            (2000, 3, 1, 11_017),
            (2024, 2, 29, 19_782),
            (2026, 10, 25, 20_751),
            (1969, 12, 31, -1),
        ]
    )
    func dayCounts(year: Int, month: Int, day: Int, expected: Int) {
        // Act
        let date = CalendarDay(year: year, month: month, day: day)

        // Assert
        #expect(date.daysSinceEpoch == expected)
    }
}
