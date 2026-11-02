import Testing

@testable import PuzzlesCore

private enum Mark: Character {
    case empty = "."
    case on = "X"
}

struct CellChangeCodecTests {
    @Test("given changes when encoded and decoded then they come back unchanged")
    func roundTrip() {
        // Arrange
        let changes: [(cell: Int, from: Mark, to: Mark)] = [(cell: 0, from: .empty, to: .on), (cell: 12, from: .on, to: .empty)]

        // Act
        let text = CellChangeCodec.encode(changes)
        let decoded = CellChangeCodec.decode(text, as: Mark.self)

        // Assert
        #expect(text == "0.X,12X.")
        #expect(decoded?.map(\.cell) == [0, 12])
        #expect(decoded?.map(\.to) == [.on, .empty])
    }

    @Test("given text with an unknown code when decoded then nothing is returned")
    func rejects() {
        // Assert
        #expect(CellChangeCodec.decode("3.Q", as: Mark.self) == nil)
    }
}
