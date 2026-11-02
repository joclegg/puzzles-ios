import PuzzlesCore
import Testing

@testable import SolitaireEngine

struct DealTests {
    private let seeds: [Int64] = [11, 22, 33]

    @Test("given a daily deal when its title is read then it names the day")
    func dailyTitle() {
        // Arrange
        let day = CalendarDay(year: 2026, month: 10, day: 5)

        // Act
        let deal = DealRef.daily(day: day, drawMode: .drawOne)

        // Assert
        #expect(deal.title == "Daily · 5 Oct")
        #expect(deal.isDaily)
        #expect(deal.slot == "daily_2026-10-05")
    }

    @Test(
        "given a draw mode and order when a random deal is titled then it shows them, in one shared slot",
        arguments: [
            (DrawMode.drawOne, BuildOrder.down, "Draw 1"),
            (DrawMode.drawThree, BuildOrder.down, "Draw 3"),
            (DrawMode.drawOne, BuildOrder.up, "Draw 1 · Reverse"),
        ]
    )
    func randomTitle(drawMode: DrawMode, order: BuildOrder, title: String) {
        // Act
        let deal = DealRef.random(seed: 1, drawMode: drawMode, order: order)

        // Assert
        #expect(deal.title == title)
        #expect(deal.slot == "deal")
    }

    @Test("given a bank when a random deal is made then the seed picks a line the same way each time")
    func randomFromBank() {
        // Act
        let picked = WinnableDeals.random(seed: 7, seeds: seeds)

        // Assert
        #expect(seeds.contains(picked))
        #expect(WinnableDeals.random(seed: 7, seeds: seeds) == picked)
    }

    @Test(
        "given a day when the daily seed is picked then it wraps on the bank size, before and after the epoch",
        arguments: [(0, Int64(11)), (4, Int64(22)), (-1, Int64(33))]
    )
    func dailyFromBank(days: Int, expected: Int64) {
        // Act
        let picked = WinnableDeals.daily(day: CalendarDay(daysSinceEpoch: days), seeds: seeds)

        // Assert
        #expect(picked == expected)
    }

    @Test("given a mode and order when the bank path is asked for then it matches the published file")
    func bankPath() {
        // Act
        let path = WinnableDeals.bankPath(drawMode: .drawThree, order: .up)

        // Assert
        #expect(path == "solitaire/drawThree_up.txt")
    }

    @Test("given bank lines when they are read then each becomes a seed, negatives included")
    func parseSeeds() {
        // Act
        let parsed = WinnableDeals.seeds(lines: ["-7062258826959519562", " 12", ""])

        // Assert
        #expect(parsed == [-7_062_258_826_959_519_562, 12])
    }

    @Test("given finished games when stats are made then abandoned count as played and only wins set the bests")
    func stats() {
        // Arrange
        let deal = DealRef.random(seed: 1, drawMode: .drawOne)
        let other = DealRef.random(seed: 1, drawMode: .drawThree)
        let games = [
            SavedGame(id: 1, deal: deal, moves: [.draw], elapsedMs: 1000, status: .won, startedAt: 0, finishedAt: 1),
            SavedGame(id: 2, deal: deal, moves: [.draw, .draw], elapsedMs: 3000, status: .won, startedAt: 0, finishedAt: 1),
            SavedGame(id: 3, deal: deal, moves: [], elapsedMs: 10, status: .abandoned, startedAt: 0, finishedAt: nil),
            SavedGame(id: 4, deal: deal, moves: [], elapsedMs: 10, status: .inProgress, startedAt: 0, finishedAt: nil),
            SavedGame(id: 5, deal: other, moves: [], elapsedMs: 10, status: .won, startedAt: 0, finishedAt: 1),
        ]

        // Act
        let result = DrawStats(drawMode: .drawOne, games: games)

        // Assert
        #expect(result.played == 3)
        #expect(result.won == 2)
        #expect(result.bestMs == 1000)
        #expect(result.averageMs == 2000)
        #expect(result.fewestMoves == 1)
        #expect(result.winRate == "66%")
    }

    @Test("given no finished games when the win rate is read then it is a dash")
    func emptyWinRate() {
        // Assert
        #expect(DrawStats(drawMode: .drawOne, games: []).winRate == "–")
    }

    @Test(
        "given a previous best when a win is timed then only a faster one is a new best",
        arguments: [(Int64(5), Int64?.none, true), (Int64(5), Int64?.some(6), true), (Int64(5), Int64?.some(5), false)]
    )
    func newBest(elapsed: Int64, previous: Int64?, expected: Bool) {
        // Assert
        #expect(isNewBest(elapsedMs: elapsed, previousBestMs: previous) == expected)
    }

    @Test(
        "given a hint when it is put in words then it says where the card goes and why",
        arguments: [
            ("5C/AH|/KS|/QH|/|/|/|/;;;|||", Selection(pile: .tableau(0), count: 1), Pile.foundation(2), "Move the A♥ to its foundation."),
            ("/AH|/KS|/QH|/|/|/|/;;;|||", Selection(pile: .tableau(2), count: 1), Pile.tableau(1), "Move the Q♥ onto the K♠."),
            (
                "5C/QH|/KS|/|/|/|/|/;;;|||", Selection(pile: .tableau(0), count: 1), Pile.tableau(1),
                "Move the Q♥ onto the K♠ to turn over the card under it."
            ),
            (
                "/|/AH|/QH|/|/|/|/;;KS;|||", Selection(pile: .waste, count: 1), Pile.tableau(0),
                "Move the K♠ from the waste to the empty column 1, so the card under it can be played."
            ),
        ]
    )
    func hint(board: String, selection: Selection, to: Pile, text: String) {
        // Act
        let words = hintText(board: BoardCodec.decode(board), selection: selection, to: to)

        // Assert
        #expect(words == text)
    }
}
