import Testing

@testable import SolitaireEngine

struct GameStateTests {
    @Test("given an ace on the tableau when it is tapped then it goes to its foundation")
    func aceGoesUp() {
        // Arrange
        let game = state("/AH|/;;;|||")

        // Act
        let after = game.tapCard(.tableau(0), index: 0)

        // Assert
        #expect(after.board.foundations[2] == [Card.parse("AH")])
    }

    @Test("given a card that fits a column and a foundation when it is tapped then the foundation wins")
    func foundationWins() {
        // Arrange
        let game = state("/2H|/3S;;;||AH|")

        // Act
        let after = game.tapCard(.tableau(0), index: 0)

        // Assert
        #expect(after.board.foundations[2].count == 2)
    }

    @Test("given a run when its first card is tapped then the whole run moves")
    func runMoves() {
        // Arrange
        let game = state("4C/TH9S|/JC;;;|||")

        // Act
        let after = game.tapCard(.tableau(0), index: 1)

        // Assert
        #expect(after.board == board("/4C|/JCTH9S;;;|||"))
    }

    @Test("given cards build up when a king is tapped then it goes to its foundation")
    func upKingGoesUp() {
        // Arrange
        let game = GameState(start: board("4C/KH|/;;;|||"), drawMode: .drawOne, order: .up)

        // Act
        let after = game.tapCard(.tableau(0), index: 1)

        // Assert
        #expect(after.board == board("/4C|/;;;||KH|"))
    }

    @Test("given a card with nowhere to go when it is tapped then it stays selected")
    func staysSelected() {
        // Arrange
        let game = state("/5H|/9C;;;|||")

        // Act
        let after = game.tapCard(.tableau(0), index: 0)

        // Assert
        #expect(after.selection == Selection(pile: .tableau(0), count: 1))
    }

    @Test("given one tap move is off when a card is tapped and then a target then the card moves to the target")
    func tapThenTarget() {
        // Arrange
        let game = state("/QH|/KS|/KC;;;|||", oneTapMove: false)

        // Act
        let after = game.tapCard(.tableau(0), index: 0).tapCard(.tableau(2), index: 0)

        // Assert
        #expect(after.board == board("/|/KS|/KCQH;;;|||"))
    }

    @Test("given a selected king when an empty column is tapped then it moves there")
    func kingToEmptyColumn() {
        // Arrange
        let game = state("QD/KH|/;;;|||", oneTapMove: false).tapCard(.tableau(0), index: 1)

        // Act
        let after = game.tapEmptyPile(.tableau(1))

        // Assert
        #expect(after.board == board("/QD|/KH;;;|||"))
    }

    @Test("given a king at the bottom of its column when it is tapped then it is not moved to an empty column")
    func bottomKingStays() {
        // Arrange
        let game = state("/KH|/;;;|||")

        // Act
        let after = game.tapCard(.tableau(0), index: 0)

        // Assert
        #expect(after.moveCount == 0)
    }

    @Test("given a face down card when it is tapped then nothing happens")
    func faceDownTap() {
        // Arrange
        let game = state("AS/KH|/;;;|||")

        // Act
        let after = game.tapCard(.tableau(0), index: 0)

        // Assert
        #expect(after.moveCount == 0)
        #expect(after.selection == nil)
    }

    @Test("given a move that turned a card over when it is undone then the card is face down again")
    func undoFlipsBack() {
        // Arrange
        let game = state("2D/AH|/;;;|||").tapCard(.tableau(0), index: 1)

        // Act
        let after = game.undo()

        // Assert
        #expect(after.board == board("2D/AH|/;;;|||"))
    }

    @Test("given several draws when they are all undone then the board is back to the deal", arguments: [1, 5, 30])
    func undoDraws(draws: Int) {
        // Arrange
        let deal = Board.deal(seed: 3)
        let played = (0..<draws).reduce(GameState(start: deal, drawMode: .drawThree)) { game, _ in game.tapStock() }

        // Act
        let undone = (0..<draws).reduce(played) { game, _ in game.undo() }

        // Assert
        #expect(undone.board == deal)
    }

    @Test("given four kings left when they all go up then the game is won and undo does nothing")
    func wonGameKeepsUndo() {
        // Arrange
        let game = state("/KC|/KD|/KH|/KS;;;\(foundationsMissingKings())")

        // Act
        let after = (0...3).reduce(game) { played, column in played.tapCard(.tableau(column), index: 0) }

        // Assert
        #expect(after.isWon)
        #expect(after == after.undo())
    }

    @Test("given an empty stock and waste when the stock is tapped then nothing changes")
    func emptyStockTap() {
        // Arrange
        let game = state("/KS;;;|||")

        // Act
        let after = game.tapStock()

        // Assert
        #expect(after.moveCount == 0)
    }

    @Test("given a restarted game when its moves are read then they are empty and the board is the deal")
    func restartClears() {
        // Arrange
        let game = state("/;2C3C;;|||").tapStock().tapStock()

        // Act
        let after = game.restart()

        // Assert
        #expect(after.board == board("/;2C3C;;|||"))
        #expect(after.selection == nil)
    }

    @Test("given a run dragged onto a column where it fits when it is dropped then it moves there")
    func dropFits() {
        // Arrange
        let game = state("4C/TH9S|/JC|/KD;;;|||")

        // Act
        let after = game.drop(from: .tableau(0), index: 1, to: .tableau(1))

        // Assert
        #expect(after.board == board("/4C|/JCTH9S|/KD;;;|||"))
    }

    @Test("given a card dropped where it does not fit when it is dropped then nothing moves")
    func dropMisfit() {
        // Arrange
        let game = state("4C/TH9S|/JC|/KD;;;|||")

        // Act
        let after = game.drop(from: .tableau(0), index: 1, to: .tableau(2))

        // Assert
        #expect(after.moveCount == 0)
    }

    @Test(
        "given a board when auto finish is checked then it is offered only with every card face up and nothing to draw",
        arguments: [
            ("/KH|/AHQS;;;|||", true),
            ("KH/|/AHQS;;;|||", false),
            ("/KH|/AH;QS;;|||", false),
            ("/KH|/AH;;QS;|||", false),
        ]
    )
    func autoFinishOffered(text: String, expected: Bool) {
        // Act
        let offered = state(text).canAutoFinish

        // Assert
        #expect(offered == expected)
    }

    @Test("given every card face up when auto finish is played then the game is won")
    func autoFinishWins() {
        // Arrange
        let game = state("/KC|/KD|/KH|/KS;;;\(foundationsMissingKings())")

        // Act
        let after = game.autoFinish()

        // Assert
        #expect(game.autoFinishMoves().count == 4)
        #expect(after.isWon)
    }

    @Test("given cards build up when auto finish is played then the foundations build down from the kings")
    func autoFinishUp() {
        // Arrange
        let foundations = Suit.allCases.map { suit in
            codes(Card.deck.filter { $0.suit == suit && $0.rank > Card.ace }.reversed())
        }.joined(separator: "|")
        let game = GameState(start: board("/AC|/AD|/AH|/AS;;;\(foundations)"), drawMode: .drawOne, order: .up)

        // Act
        let after = game.autoFinish()

        // Assert
        #expect(after.isWon)
    }

    @Test("given a face down card when auto finish is played then nothing changes")
    func autoFinishBlocked() {
        // Arrange
        let game = state("KH/AH|/;;;|||")

        // Act
        let after = game.autoFinish()

        // Assert
        #expect(after == game)
    }

    @Test(
        "given three cards to draw when the stock is drawn some times then it counts as cycled only after a full pass",
        arguments: [(0, false), (3, false), (4, true)]
    )
    func cycledAfterFullPass(draws: Int, expected: Bool) {
        // Arrange
        let game = state("/KH|/;2C3C4C;;|||")

        // Act
        let drawn = (0..<draws).reduce(game) { played, _ in played.tapStock() }

        // Assert
        #expect(drawn.cycledStock == expected)
    }

    @Test("given a full pass when a card is played then the stock is no longer cycled")
    func playResetsCycle() {
        // Arrange
        let cycled = (0..<4).reduce(state("/4S|/;5C3H;;|||")) { played, _ in played.tapStock() }

        // Act
        let played = cycled.drop(from: .waste, index: cycled.board.waste.count - 1, to: .tableau(0)).tapStock()

        // Assert
        #expect(cycled.cycledStock)
        #expect(!played.cycledStock)
    }

    @Test(
        "given draw three and a played card when the stock is drawn then it is cycled only after a whole pass from the turn over",
        arguments: [(3, false), (4, false), (5, true)]
    )
    func drawThreeCycle(draws: Int, expected: Bool) {
        // Arrange
        let drawnOnce = GameState(start: board("/KH|/;2C3C4C5CQS7C6C;;|||"), drawMode: .drawThree).tapStock()
        let played = drawnOnce.drop(from: .waste, index: drawnOnce.board.waste.count - 1, to: .tableau(0))

        // Act
        let drawn = (0..<draws).reduce(played) { game, _ in game.tapStock() }

        // Assert
        #expect(drawn.cycledStock == expected)
    }

    @Test("given nothing left to draw when the stock is checked then it counts as cycled")
    func nothingToDraw() {
        // Act
        let cycled = state("/KH|/QS;;;|||").cycledStock

        // Assert
        #expect(cycled)
    }
}
