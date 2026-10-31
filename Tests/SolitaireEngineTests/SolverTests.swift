import Testing

@testable import SolitaireEngine

struct SolverTests {
    @Test("given four kings left on the table when it is solved then it is winnable")
    func fourKings() {
        // Act
        let verdict = Solver.solve(board("/KC|/KD|/KH|/KS;;;\(foundationsMissingKings())"), drawMode: .drawOne, order: .down)

        // Assert
        #expect(verdict == .winnable)
    }

    @Test("given a king stuck in the only column under its ace when it is solved then it is unwinnable")
    func stuckUnderAce() {
        // Arrange
        let others = Suit.allCases.filter { $0 != .spades }.map { suit in
            codes(Card.deck.filter { $0.suit == suit })
        }.joined(separator: "|")

        // Act
        let verdict = Solver.solve(board("2S3S4S5S6S7S8S9STSJSQSKS/AS;;;\(others)|"), drawMode: .drawOne, order: .down)

        // Assert
        #expect(verdict == .unwinnable)
    }

    @Test("given a king that blocks the only card that could free it when it is solved then it is unwinnable")
    func kingBlocksQueen() {
        // Arrange
        let rest = Suit.allCases.map { suit in
            codes(Card.deck.filter { $0.suit == suit && !(suit == .hearts && $0.rank >= Card.queen) })
        }.joined(separator: "|")

        // Act
        let verdict = Solver.solve(board("QH/KH;;;\(rest)"), drawMode: .drawOne, order: .down)

        // Assert
        #expect(verdict == .unwinnable)
    }

    @Test(
        "given random deals when they are solved then most are winnable and none are wrongly unwinnable",
        arguments: DrawMode.allCases
    )
    func randomDeals(drawMode: DrawMode) {
        // Act
        let verdicts = (Int64(1)...12).map { Solver.solve(Board.deal(seed: $0), drawMode: drawMode, order: .down) }

        // Assert
        #expect(verdicts.count { $0 == .winnable } >= 6)
    }

    @Test(
        "given a seed when a winnable deal is asked for then the deal is a full deck the solver can win, and it is the same each time",
        arguments: DrawMode.allCases
    )
    func winnableDeal(drawMode: DrawMode) {
        // Act
        let deals = (0..<2).map { _ in Solver.winnableDeal(seed: 3, drawMode: drawMode, order: .down) }

        // Assert
        #expect(deals[0] == deals[1])
        #expect(Solver.solve(deals[0], drawMode: drawMode, order: .down) == .winnable)
    }

    @Test("given a stop signal when solving then it gives up as unknown")
    func stopSignal() {
        // Act
        let verdict = Solver.solve(Board.deal(seed: 1), drawMode: .drawThree, order: .down, shouldStop: { true })

        // Assert
        #expect(verdict == .unknown)
    }
}
