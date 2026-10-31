import Testing

@testable import PuzzlesCore

@Suite struct DailyMedalTests {
    private let day = CalendarDay(year: 2026, month: 10, day: 31)

    @Test(
        "given a count of dailies when the medal is chosen then it follows the rule",
        arguments: [
            (0, 12, Medal.bronze, Medal.none),
            (1, 12, Medal.bronze, Medal.bronze),
            (2, 12, Medal.bronze, Medal.silver),
            (12, 12, Medal.bronze, Medal.gold),
            (1, 2, Medal.silver, Medal.silver),
            (2, 2, Medal.silver, Medal.gold),
            (1, 1, Medal.bronze, Medal.gold),
        ])
    func medal(count: Int, total: Int, first: Medal, expected: Medal) {
        // Act
        let medal = medalFor(count: count, total: total, firstMedal: first)

        // Assert
        #expect(medal == expected)
    }

    @Test("given results on the day and later when grouped then only those on the day earn a medal")
    func days() {
        // Arrange
        let later = day.adding(days: 1)
        let results = [
            DailyResult(date: day, id: "a", finishedOn: day),
            DailyResult(date: day, id: "a", finishedOn: day),
            DailyResult(date: later, id: "b", finishedOn: later.adding(days: 1)),
        ]

        // Act
        let grouped = dailyDays(results: results, total: 3)

        // Assert
        #expect(grouped[day] == DailyDay(date: day, medal: .bronze, doneLate: false))
        #expect(grouped[later] == DailyDay(date: later, medal: .none, doneLate: true))
    }

    @Test(
        "given a saved game id when its date is read then only daily ids have one",
        arguments: [
            ("daily_2026-10-31", true),
            ("daily2_2026-10-31", true),
            ("nyt_2026-10-31", true),
            ("daily_2026-10-31_8", true),
            ("daily_2026-10-31_hard", true),
            ("daily_2026-13-31", false),
            ("daily_2026-02-30", false),
            ("daily_2026-10-31x", false),
            ("practice_2026-10-31", false),
            ("fixture_one", false),
        ])
    func date(id: String, hasDate: Bool) {
        // Act
        let date = dailyDate(fromId: id)

        // Assert
        #expect((date != nil) == hasDate)
    }
}
