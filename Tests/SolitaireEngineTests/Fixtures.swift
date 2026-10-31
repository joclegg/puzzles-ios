@testable import SolitaireEngine

func board(_ text: String) -> Board {
    BoardCodec.decode(text)
}

func state(_ text: String, drawMode: DrawMode = .drawOne, oneTapMove: Bool = true) -> GameState {
    GameState(start: board(text), drawMode: drawMode, oneTapMove: oneTapMove)
}

func codes(_ cards: [Card]) -> String {
    cards.map(\.code).joined()
}

let fullFoundations = Suit.allCases.map { suit in
    codes(Card.deck.filter { $0.suit == suit })
}.joined(separator: "|")

func foundationsMissingKings() -> String {
    Suit.allCases.map { suit in
        codes(Card.deck.filter { $0.suit == suit && $0.rank < Card.king })
    }.joined(separator: "|")
}
