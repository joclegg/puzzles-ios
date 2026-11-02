import Testing

@testable import PuzzlesCore

struct DailyIdTests {
    @Test("given a date and suffix when a daily id is made then it reads back as a daily on that date")
    func roundTrip() {
        // Arrange
        let date = CalendarDay(year: 2026, month: 3, day: 7)

        // Act
        let id = DailyId.make(date: date, suffix: "6")

        // Assert
        #expect(id == "daily_2026-03-07_6")
        #expect(DailyId.isDaily(id))
        #expect(DailyId.isoDate(of: id) == "2026-03-07")
        #expect(!DailyId.isDaily("random_42"))
    }

    @Test(
        "given an iso date when labelled then it shows the day and short month",
        arguments: [("2026-03-07", "7 Mar"), ("2026-12-25", "25 Dec"), ("bad", "bad"), ("2026-13-01", "2026-13-01")])
    func dayMonth(iso: String, text: String) {
        // Assert
        #expect(dayMonthLabel(iso: iso) == text)
    }

    @Test("given a size when labelled then it reads as a grid")
    func size() {
        // Assert
        #expect(sizeLabel(8) == "8 x 8")
    }
}
