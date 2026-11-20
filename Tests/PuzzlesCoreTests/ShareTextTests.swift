import Testing

@testable import PuzzlesCore

@Suite struct ShareTextTests {
    private let day = CalendarDay(year: 2026, month: 11, day: 20)

    @Test("given the spec example when the dailies are shared then the text matches it")
    func dailies() {
        // Arrange
        let body = [
            DailyShareEntry(label: "Easy", timeMs: 151_000, bestMs: 120_000),
            DailyShareEntry(label: "Medium", timeMs: 252_000, bestMs: 252_000),
            DailyShareEntry(label: "Hard", timeMs: 588_000, bestMs: 500_000),
            DailyShareEntry(label: "Expert", timeMs: nil),
        ].map(dailyShareLine)
        let medals: [CalendarDay: Medal] = [
            day.adding(days: -6): .gold, day.adding(days: -5): .gold, day.adding(days: -4): .silver,
            day.adding(days: -3): .gold, day.adding(days: -2): .gold, day: .silver,
        ]

        // Act
        let text = dailiesShareText(
            game: "Sudoku", date: day, medal: .silver, body: body, lastSeven: lastSevenMedals(medals, ending: day))

        // Assert
        #expect(
            text
                == "Sudoku · 20 Nov 🥈\nEasy 2:31\nMedium 4:12 ⭐\nHard 9:48\nExpert ⬛\n\nLast 7 days 🟨🟨⬜🟨🟨⬛⬜\njoclegg.github.io/puzzles-web"
        )
    }

    @Test("given no medal when the dailies are shared then the title has no emoji")
    func noMedal() {
        // Act
        let text = dailiesShareText(
            game: "Solitaire", date: day, medal: .none, body: [solitaireDailyLine(wonMs: nil)],
            lastSeven: Array(repeating: .none, count: 7))

        // Assert
        #expect(text == "Solitaire · 20 Nov\nNot won\n\nLast 7 days ⬛⬛⬛⬛⬛⬛⬛\njoclegg.github.io/puzzles-web")
    }

    @Test("given a slide out daily when its line is built then it shows the moves before the star")
    func slideOutLine() {
        // Act
        let line = dailyShareLine(DailyShareEntry(label: "Easy", timeMs: 65_000, bestMs: 65_000, moves: 12))

        // Assert
        #expect(line == "Easy 1:05 · 12 moves ⭐")
    }

    @Test("given records when they are shared then the text has the lines and summary")
    func records() {
        // Act
        let text = recordsShareText(
            game: "Kakuro", lines: [recordLine(label: "6 x 6", bestMs: 95_000)],
            summary: solvedSummary(count: 14, streak: DailyStreak(current: 3, longest: 9)))

        // Assert
        #expect(text == "Kakuro records 🏆\n6 x 6 1:35\n\n14 solved · 🔥 3 · longest 🔥 9\njoclegg.github.io/puzzles-web")
    }

    @Test("given solitaire records when summarised then wins and the rounded down percent are shown")
    func solitaire() {
        // Act
        let lines = solitaireRecordLines(fastestMs: 200_000, fewestMoves: 90)
        let summary = solitaireSummary(wins: 2, played: 3, streak: DailyStreak(current: 0, longest: 1))

        // Assert
        #expect(lines == ["Fastest win 3:20", "Fewest moves 90"])
        #expect(summary == "2 wins · 66% · 🔥 0 · longest 🔥 1")
    }

    @Test("given guess counts when charted then the largest bucket has eight squares")
    func chart() {
        // Act
        let lines = guessChartLines(counts: [0, 1, 4, 8, 2, 0])

        // Assert
        #expect(lines[0] == "1  0")
        #expect(lines[1] == "2 🟩 1")
        #expect(lines[2] == "3 🟩🟩🟩🟩 4")
        #expect(lines[3] == "4 🟩🟩🟩🟩🟩🟩🟩🟩 8")
    }

    @Test("given solved days when the streak is counted then today or yesterday starts it")
    func streak() {
        // Arrange
        let days: Set<CalendarDay> = [
            day.adding(days: -1), day.adding(days: -2), day.adding(days: -10), day.adding(days: -11),
            day.adding(days: -12), day.adding(days: -13),
        ]

        // Act
        let streak = dailyStreak(days: days, today: day)

        // Assert
        #expect(streak == DailyStreak(current: 2, longest: 4))
    }

    @Test("given a daily 2 share when the five letters body is built then a blank line separates them")
    func fiveLetters() {
        // Act
        let body = fiveLettersDailiesBody(puzzles: "A", daily2: "B")

        // Assert
        #expect(body == ["A", "", "B"])
    }
}
