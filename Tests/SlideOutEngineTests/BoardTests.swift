import Testing

@testable import SlideOutEngine

private let board = try! Board.decode("202H,033V,412H")

struct BoardTests {
    @Test(
        "given blocks when a block's range is found then it stops at the edges and other blocks",
        arguments: [(0, 0, 1), (1, 0, 3), (2, 0, 4)]
    )
    func rangeStops(block: Int, low: Int, high: Int) {
        // Act
        let range = board.range(block)

        // Assert
        #expect(range == low...high)
    }

    @Test("given a board when it is encoded and decoded then it is unchanged")
    func roundTrip() throws {
        // Act
        let decoded = try Board.decode(board.encode())

        // Assert
        #expect(decoded == board)
    }

    @Test("given the red block at the right edge when the board is checked then it is solved")
    func solvedAtEdge() throws {
        // Act
        let solved = try Board.decode("242H").isSolved

        // Assert
        #expect(solved)
    }

    @Test("given the same blocks in another order when identified then the identities match")
    func identitiesMatch() throws {
        // Arrange
        let reordered = try Board.decode("202H,412H,033V")

        // Act
        let identities = (board.identity(), reordered.identity())

        // Assert
        #expect(identities.0 == identities.1)
    }

    @Test("given a different red block when identified then the identities differ")
    func identitiesDiffer() throws {
        // Arrange
        let other = try Board.decode("412H,202H,033V")

        // Act
        let identities = (board.identity(), other.identity())

        // Assert
        #expect(identities.0 != identities.1)
    }

    @Test("given malformed text when a board is decoded then it throws", arguments: ["", "20", "x02H", "202H,"])
    func malformedThrows(text: String) {
        // Assert
        #expect(throws: DecodeError.self) { try Board.decode(text) }
    }
}
