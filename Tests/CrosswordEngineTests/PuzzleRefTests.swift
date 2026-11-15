import PuzzlesCore
import Testing

@testable import CrosswordEngine

struct PuzzleRefTests {
    private let bank = (0..<9).map { _ in small }
    private let day = CalendarDay(year: 2026, month: 11, day: 16)

    @Test("given a date and size when the daily id is made then it matches Android's format")
    func dailyIdFormat() {
        // Act
        let id = PuzzleRef.dailyId(date: day, size: 13)

        // Assert
        #expect(id == "daily_2026-11-16_13")
    }

    @Test("given consecutive days across a full cycle when dailies are picked then every line is used once")
    func dailyCycles() {
        // Act
        let picked = (0..<9).map { PuzzleRef.dailyIndex(count: 9, date: day.adding(days: $0), size: 11) }

        // Assert
        #expect(Set(picked).count == 9)
    }

    @Test("given a bank longer than the daily pool when dailies are picked then lines past the pool are never used")
    func dailyPoolIsFixed() {
        // Act
        let picked = (0..<400).map { PuzzleRef.dailyIndex(count: 5000, date: day.adding(days: $0 * 7), size: 15) }
        let grown = (0..<400).map { PuzzleRef.dailyIndex(count: 3000, date: day.adding(days: $0 * 7), size: 15) }

        // Assert
        #expect(picked.allSatisfy { $0 < dailyPoolSize })
        #expect(picked == grown)
    }

    @Test("given a daily ref when titled then it shows the date and size name")
    func titles() {
        // Arrange
        let daily = PuzzleRef.daily(puzzles: bank, date: day, size: 3)
        let random = PuzzleRef.random(puzzles: bank, size: 3, seed: 7)

        // Assert
        #expect(daily.title == "Daily · 16 Nov · 3 x 3")
        #expect(random.id.hasPrefix("bank_3_"))
        #expect(random.slot == "size_3")
    }

    @Test("given finished games when stats are made then abandoned games count as played")
    func stats() {
        // Arrange
        let ref = PuzzleRef(id: "x", puzzle: small)
        let games = [
            SavedGame(id: 1, ref: ref, elapsedMs: 100, status: .solved, startedAt: 0),
            SavedGame(id: 2, ref: ref, elapsedMs: 300, status: .solved, startedAt: 0),
            SavedGame(id: 3, ref: ref, status: .abandoned, startedAt: 0),
            SavedGame(id: 4, ref: ref, status: .inProgress, startedAt: 0),
        ]

        // Act
        let stats = SizeStats.of(size: 3, games: games)

        // Assert
        #expect(stats == SizeStats(size: 3, played: 3, solved: 2, bestMs: 100, averageMs: 200))
    }
}
