import Testing

@testable import SolitaireEngine

private let draws: [(String, DrawMode, String)] = [
    ("/;2C3C4C;;|||", .drawOne, "/;2C3C;4C;|||"),
    ("/;2C3C4C5C;AC;|||", .drawThree, "/;2C;AC5C4C3C;|||"),
    ("/;2C;;|||", .drawThree, "/;;2C;|||"),
    ("/;;2C3C4C;|||", .drawOne, "/;4C3C2C;;|||"),
]

private let upMoves: [(String, Pile, Int, Pile, Bool)] = [
    ("/2H|/AS;;;|||", .tableau(0), 1, .tableau(1), true),
    ("/QH|/KS;;;|||", .tableau(0), 1, .tableau(1), false),
    ("/AHQS|/;;;|||", .tableau(0), 1, .tableau(1), false),
    ("/AH2S|/;;;|||", .tableau(0), 2, .tableau(1), true),
    ("/KH|/;;;|||", .tableau(0), 1, .tableau(1), false),
    ("/KS;;;|||", .tableau(0), 1, .foundation(3), true),
    ("/AS;;;|||", .tableau(0), 1, .foundation(3), false),
    ("/QS;;;|||KS", .tableau(0), 1, .foundation(3), true),
    ("/JS;;;|||KS", .tableau(0), 1, .foundation(3), false),
]

private let downMoves: [(String, Pile, Int, Pile, Bool)] = [
    ("/QH|/KS;;;|||", .tableau(0), 1, .tableau(1), true),
    ("/QS|/KS;;;|||", .tableau(0), 1, .tableau(1), false),
    ("/QH|/;;;|||", .tableau(0), 1, .tableau(1), false),
    ("/KH|/;;;|||", .tableau(0), 1, .tableau(1), true),
    ("/KHQS|/;;;|||", .tableau(0), 2, .tableau(1), true),
    ("KH/QS|/;;;|||", .tableau(0), 2, .tableau(1), false),
    ("/KHQH|/;;;|||", .tableau(0), 2, .tableau(1), false),
    ("/AS;;;|||", .tableau(0), 1, .foundation(3), true),
    ("/AS;;;|||", .tableau(0), 1, .foundation(0), false),
    ("/2S;;;|||AS", .tableau(0), 1, .foundation(3), true),
    ("/3S;;;|||AS", .tableau(0), 1, .foundation(3), false),
    ("/;;AH;|||", .waste, 1, .foundation(2), true),
    ("/2H;;;||AH|", .foundation(2), 1, .tableau(0), false),
    ("/2S;;;|AD||", .foundation(1), 1, .tableau(0), true),
    ("/KS;;;|||", .tableau(0), 1, .waste, false),
]

struct BoardTests {
    @Test("given a seed when a deal is made then columns hold one to seven cards with only the top face up")
    func dealShape() {
        // Act
        let dealt = Board.deal(seed: 42)

        // Assert
        #expect(dealt.tableau.map(\.cards.count) == Array(1...7))
        #expect(dealt.tableau.map(\.faceUpFrom) == Array(0...6))
        #expect(dealt.stock.count == 24)
    }

    @Test("given the same seed when two deals are made then they match")
    func dealRepeats() {
        // Act
        let deals = [Board.deal(seed: 7), Board.deal(seed: 7), Board.deal(seed: 8)]

        // Assert
        #expect(deals[0] == deals[1])
        #expect(deals[0] != deals[2])
    }

    @Test(
        "given a seed when a deal is made then it deals the same cards as Android and puzzles-web",
        arguments: [
            (
                Int64(42),
                "/7C|TS/QC|9C7H/6D|KC4DAD/6S|2H4H7D5H/5S|4C7S9D8H3H/TH|6HKHJS5DAH2C/2D;QS9S3C8DJCTDACQD2S9HJDAS8C5C8SKDKSTC3DQHJH3S4S6C;;|||"
            ),
            (
                Int64(-1),
                "/QH|2H/TS|3CJD/JS|5SQD9H/7H|6S2SAS2D/4D|TH4C6DAC8C/5D|7SADTDQS8DKS/7D;3D9CKH3S4S6C3HAH7C8H2CTC9D6HJCKCJH4HKD5C8SQC9S5H;;|||"
            ),
        ]
    )
    func dealMatchesOtherApps(seed: Int64, expected: String) {
        // Act
        let dealt = Board.deal(seed: seed)

        // Assert
        #expect(BoardCodec.encode(dealt) == expected)
    }

    @Test("given a stock when drawing then cards move to the waste or the waste turns over", arguments: draws)
    func drawing(before: String, drawMode: DrawMode, after: String) {
        // Act
        let drawn = board(before).draw(drawMode)

        // Assert
        #expect(drawn == board(after))
    }

    @Test("given a board when a move is checked then only legal moves are allowed", arguments: downMoves)
    func legalMoves(text: String, from: Pile, count: Int, to: Pile, legal: Bool) {
        // Act
        let result = board(text).canMove(from: from, count: count, to: to)

        // Assert
        #expect(result == legal)
    }

    @Test("given cards build up when a move is checked then only legal moves are allowed", arguments: upMoves)
    func legalUpMoves(text: String, from: Pile, count: Int, to: Pile, legal: Bool) {
        // Act
        let result = board(text).canMove(from: from, count: count, to: to, order: .up)

        // Assert
        #expect(result == legal)
    }

    @Test("given a column with a face down card when its top card moves away then the next card turns face up")
    func revealsNextCard() {
        // Arrange
        let before = board("KS/QH|/;;;|||")

        // Act
        let after = before.move(from: .tableau(0), count: 1, to: .tableau(1))

        // Assert
        #expect(after == board("/KS|/QH;;;|||"))
    }

    @Test("given four full foundations when the board is checked then it is won")
    func fullFoundationsWin() {
        // Act
        let won = board("/;;;\(fullFoundations)").isWon

        // Assert
        #expect(won)
    }
}
