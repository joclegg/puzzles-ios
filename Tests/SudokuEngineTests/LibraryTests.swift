import PuzzlesCore
import Testing

@testable import SudokuEngine

@Suite struct LibraryTests {
    private let day = CalendarDay(year: 2026, month: 10, day: 31)

    @Test("given a daily id when parsed then the mode and date come back")
    func dailyIdRoundTrip() throws {
        // Act
        let parsed = try #require(DailyIds.parse(DailyIds.of(mode: .killer, date: day)))

        // Assert
        #expect(DailyIds.of(mode: .killer, date: day) == "daily_killer:2026-10-31")
        #expect(parsed.mode == .killer)
        #expect(parsed.date == day)
    }

    @Test(
        "given a non daily id when parsed then nothing comes back",
        arguments: ["classic_easy:3", "daily_", "daily_other:2026-10-31", "daily_classic:soon"])
    func invalidDailyId(id: String) {
        // Assert
        #expect(DailyIds.parse(id) == nil)
    }

    @Test("given finishes on the day and later when grouped then the medal follows the rules")
    func medals() {
        // Arrange
        let classic = DailyIds.of(mode: .classic, date: day)
        let killer = DailyIds.of(mode: .killer, date: day)
        let later = day.adding(days: 1)

        // Act
        let silver = dailyDays(completed: [DailyFinish(puzzleId: classic, finishedOn: day)])[day]
        let gold = dailyDays(completed: [
            DailyFinish(puzzleId: classic, finishedOn: day), DailyFinish(puzzleId: killer, finishedOn: day),
        ])[day]
        let late = dailyDays(completed: [DailyFinish(puzzleId: classic, finishedOn: later)])[day]
        let lateThenOnTime = dailyDays(completed: [
            DailyFinish(puzzleId: classic, finishedOn: later), DailyFinish(puzzleId: classic, finishedOn: day),
        ])[day]

        // Assert
        #expect(silver?.medal == .silver)
        #expect(gold?.medal == .gold)
        #expect(late?.medal == Medal.none)
        #expect(late?.doneLate == true)
        #expect(lateThenOnTime?.status(.classic) == .onTheDay)
    }

    @Test("given a date when the daily is picked then level and index are stable and in range")
    func dailyPick() {
        // Act
        let level = BankPick.dailyLevel(mode: .killer, date: day)
        let index = BankPick.dailyIndex(mode: .killer, date: day, size: 10)

        // Assert
        #expect(killerLevels.contains(level))
        #expect(level == BankPick.dailyLevel(mode: .killer, date: day))
        #expect((0..<10).contains(index))
    }

    @Test("given puzzle refs when asked for their slot then each kind has its own")
    func slots() {
        // Arrange
        let puzzle = Puzzle(givens: Grid.fast.emptyValues(), solution: nil)

        // Assert
        #expect(PuzzleRef(id: "a", mode: .classic, difficulty: .easy, puzzle: puzzle).slot == "CLASSIC_EASY")
        #expect(PuzzleRef(id: "a", mode: .killer, difficulty: nil, puzzle: puzzle, custom: true).slot == "custom")
        #expect(PuzzleRef(id: "daily_classic:x", mode: .classic, difficulty: .easy, puzzle: puzzle).slot == "daily_classic:x")
    }

    @Test(
        "given a duration when formatted then hours only show when needed",
        arguments: [(Int64(0), "0:00"), (65_000, "1:05"), (3_725_000, "1:02:05")])
    func durations(ms: Int64, text: String) {
        // Assert
        #expect(formatDuration(ms) == text)
    }

    @Test("given a game when titled then kind and level show")
    func titles() {
        // Assert
        #expect(gameTitle(killer: false, custom: false, difficulty: .easy) == "Classic · Easy")
        #expect(gameTitle(killer: true, custom: true, difficulty: nil, answerKnown: false) == "Custom killer")
        #expect(gameTitle(killer: false, custom: true, difficulty: nil) == "Custom · Expert+")
    }

    @Test("given played and past times when combined then best takes both and average only played")
    func bests() {
        // Arrange
        let played = [
            FinishedGame(mode: .classic, difficulty: .easy, elapsedMs: 100),
            FinishedGame(mode: .classic, difficulty: .easy, elapsedMs: 300),
        ]
        let past = [
            FinishedGame(mode: .classic, difficulty: .easy, elapsedMs: 50),
            FinishedGame(mode: .killer, difficulty: .evil, elapsedMs: 70),
        ]

        // Act
        let times = bestTimes(finished: played, past: past)

        // Assert
        #expect(times.count == 2)
        #expect(times[0] == BestTime(mode: .classic, difficulty: .easy, bestMs: 50, averageMs: 200, completed: 2))
        #expect(times[1] == BestTime(mode: .killer, difficulty: .evil, bestMs: 70, averageMs: 0, completed: 0))
    }

    @Test("given nothing stored when settings load then defaults apply, grey cells off in killer")
    func settingDefaults() {
        // Act
        let classic = ModeSettings(mode: .classic, bool: { _ in nil }, string: { _ in nil })
        let killer = ModeSettings(mode: .killer, bool: { _ in nil }, string: { _ in nil })

        // Assert
        #expect(classic.isOn(.greyGivenCells))
        #expect(!killer.isOn(.greyGivenCells))
        #expect(killer.isOn(.showTimer))
        #expect(classic.mistakeCheck == .showWrong)
    }

    @Test("given stored values when settings load then they are read under prefixed keys")
    func settingStored() {
        // Act
        let loaded = ModeSettings(
            mode: .killer,
            bool: { $0 == "sudoku_show_timer_killer" ? false : nil },
            string: { $0 == "sudoku_mistakes_killer" ? "OFF" : nil }
        )

        // Assert
        #expect(!loaded.isOn(.showTimer))
        #expect(loaded.mistakeCheck == .off)
        #expect(!loaded.playOptions.highlightLastPlaced == false)
    }
}
