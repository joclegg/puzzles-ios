import Testing

@testable import PuzzlesCore

struct DurationTests {
    @Test(
        "given a duration when formatted then hours only show when needed",
        arguments: [
            (Int64(0), "0:00"),
            (Int64(9_999), "0:09"),
            (Int64(65_000), "1:05"),
            (Int64(3_605_000), "1:00:05"),
            (Int64(3_661_000), "1:01:01"),
            (Int64(3_725_000), "1:02:05"),
            (Int64(36_610_999), "10:10:10"),
        ]
    )
    func duration(ms: Int64, text: String) {
        // Act
        let formatted = formatDuration(ms)

        // Assert
        #expect(formatted == text)
    }
}
