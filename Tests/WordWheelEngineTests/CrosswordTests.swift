import Testing

@testable import WordWheelEngine

private let crossword = Crossword(placements: [Placement(word: "PARADE", row: 0, col: 0, across: true)])

struct CrosswordTests {
    @Test(
        "given a word on the grid when another is placed then it must cross and not touch side by side",
        arguments: [
            ("DRAPE", 0, 5, false, false),
            ("DARE", -3, 5, false, true),
            ("READ", 0, 3, false, false),
            ("AREA", 0, 1, false, true),
            ("PARE", 1, 0, true, false),
            ("DEAR", 0, 6, false, false),
        ]
    )
    func canPlace(word: String, row: Int, col: Int, across: Bool, allowed: Bool) {
        // Act
        let result = crossword.canPlace(Placement(word: word, row: row, col: col, across: across))

        // Assert
        #expect(result == allowed)
    }

    @Test("given a crossword when it is encoded and decoded then it is unchanged", arguments: ["PARADE@0,0,A|AREA@0,1,D"])
    func roundTrip(text: String) throws {
        // Act
        let decoded = try Crossword.decode(text)

        // Assert
        #expect(decoded.encode() == text)
    }
}
