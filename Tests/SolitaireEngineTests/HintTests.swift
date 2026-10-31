import Testing

@testable import SolitaireEngine

struct HintTests {
    @Test("given an ace on a column when a hint is asked for then it sends the ace up")
    func aceGoesUp() {
        // Arrange
        let game = GameState(start: board("/AH|/|/|/|/|/|/;;;|||"), drawMode: .drawOne)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint == .transfer(selection: Selection(pile: .tableau(0), count: 1), to: .foundation(2)))
    }

    @Test("given no card can move when a hint is asked for then it says to draw")
    func saysDraw() {
        // Arrange
        let game = GameState(start: board("/|/|/|/|/|/|/;2C;;|||"), drawMode: .drawOne)

        // Act
        let hint = game.findHint()

        // Assert
        #expect(hint == .draw)
    }
}
