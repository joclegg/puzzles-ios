import Testing

@testable import CrosswordEngine

struct BoardTests {
    @Test("given a grid when it is numbered then numbers run in reading order")
    func numbering() {
        // Assert
        #expect(small.numbers == [0: 1, 2: 2, 6: 3])
        #expect(small.words.map(\.label) == ["1 Across", "3 Across", "1 Down", "2 Down"])
        #expect(small.words.map { small.answer($0) } == ["CAT", "BOW", "CAB", "TOW"])
    }

    @Test("given a bank line when it is decoded then it round-trips and every word is three letters or more")
    func decodeBankLine() throws {
        // Act
        let decoded = try #require(Puzzle.decode(bankLine))

        // Assert
        #expect(decoded.size == 11)
        #expect(decoded.encode() == bankLine)
        #expect(decoded.words.allSatisfy { $0.cells.count >= 3 })
        #expect(decoded.words.first?.label == "1 Across")
    }

    @Test("given malformed lines when they are decoded then they are rejected")
    func decodeRejects() {
        // Assert
        #expect(Puzzle.decode("3;CAT") == nil)
        #expect(Puzzle.decode("3;cat#a#bow") == nil)
        #expect(Puzzle.decode("x;CATA#OBOW") == nil)
    }

    @Test("given clue lines when they are parsed then a clue shows with its enumeration")
    func clueText() {
        // Arrange
        let clues = ClueBook.parse(["CAT;Pet that purrs", "BOW;Ribbon knot", "broken"])

        // Act
        let text = ClueBook.text(for: small.words[0], in: small, clues: clues)

        // Assert
        #expect(clues.count == 2)
        #expect(text == "Pet that purrs (3)")
    }

    @Test("given sizes when they are named then they read Small, Medium and Large")
    func names() {
        // Assert
        #expect(sizes.map(sizeName) == ["Small", "Medium", "Large"])
    }
}
