import Testing

@testable import SolitaireEngine

struct CardTests {
    @Test(
        "given a card code when it is parsed then rank and suit match",
        arguments: [
            ("AS", 1, Suit.spades),
            ("TD", 10, Suit.diamonds),
            ("KH", 13, Suit.hearts),
            ("7C", 7, Suit.clubs),
        ]
    )
    func parsing(code: String, rank: Int, suit: Suit) {
        // Act
        let card = Card.parse(code)

        // Assert
        #expect(card == Card(rank: rank, suit: suit))
    }

    @Test(
        "given two cards when stacking is checked then only one lower in the other colour fits",
        arguments: [
            ("6H", "7S", true),
            ("6S", "7H", true),
            ("6H", "7D", false),
            ("5H", "7S", false),
            ("7S", "6H", false),
        ]
    )
    func stacking(moving: String, target: String, fits: Bool) {
        // Act
        let result = Card.parse(moving).stacksOnTableau(Card.parse(target))

        // Assert
        #expect(result == fits)
    }

    @Test("given the deck when it is counted then it has 52 different cards")
    func deckCount() {
        // Act
        let deck = Card.deck

        // Assert
        #expect(Set(deck).count == 52)
    }
}
