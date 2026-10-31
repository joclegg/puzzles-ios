import Testing

@testable import SolitaireEngine

struct CodecTests {
    @Test("given a deal when it is encoded and decoded then it is unchanged", arguments: [Int64(1), 99, 123_456])
    func boardRoundTrip(seed: Int64) {
        // Arrange
        let deal = Board.deal(seed: seed).draw(.drawThree)

        // Act
        let decoded = BoardCodec.decode(BoardCodec.encode(deal))

        // Assert
        #expect(decoded == deal)
    }

    @Test("given every kind of move when they are encoded and decoded then they are unchanged")
    func movesRoundTrip() {
        // Arrange
        let moves: [Move] = [
            .draw,
            .transfer(from: .waste, count: 1, to: .foundation(2)),
            .transfer(from: .tableau(6), count: 12, to: .tableau(0)),
            .transfer(from: .foundation(3), count: 1, to: .tableau(4)),
        ]

        // Act
        let decoded = MoveCodec.decode(MoveCodec.encode(moves))

        // Assert
        #expect(decoded == moves)
    }
}
