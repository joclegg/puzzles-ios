import Testing

@testable import KakuroEngine

struct BoardTests {
    @Test("given a filled grid when its runs are found then each has its cells, sum and clue cell")
    func runs() {
        // Act
        let runs = small.runs

        // Assert
        #expect(
            runs == [
                Run(cells: [4, 5], sum: 3, isAcross: true, clueCell: 3),
                Run(cells: [7, 8], sum: 7, isAcross: true, clueCell: 6),
                Run(cells: [4, 7], sum: 4, isAcross: false, clueCell: 1),
                Run(cells: [5, 8], sum: 6, isAcross: false, clueCell: 2),
            ]
        )
    }

    @Test(
        "given a run length and sum when combinations are listed then every set of different digits that adds up is there",
        arguments: [
            (length: 2, sum: 3, expected: "1 2"),
            (length: 2, sum: 17, expected: "8 9"),
            (length: 3, sum: 6, expected: "1 2 3"),
            (length: 2, sum: 10, expected: "1 9;2 8;3 7;4 6"),
        ]
    )
    func combinations(run: (length: Int, sum: Int, expected: String)) {
        // Act
        let combos = Combinations.masks(length: run.length, sum: run.sum).map { mask in
            Combinations.digitsOf(mask).map(String.init).joined(separator: " ")
        }

        // Assert
        #expect(Set(combos) == Set(run.expected.split(separator: ";").map(String.init)))
    }

    @Test("given a puzzle when it is encoded and decoded then it is unchanged")
    func roundTrip() {
        // Arrange
        let puzzle = Puzzle(size: small.size, solution: small.solution, givens: [4])

        // Act
        let decoded = Puzzle.decode(puzzle.encode())

        // Assert
        #expect(decoded == puzzle)
    }

    @Test("given a bank line when it is decoded and encoded then the text is unchanged")
    func bankLineRoundTrip() {
        // Arrange
        let line = "6;000000012300045600078900000000000000;9,14"

        // Act
        let encoded = Puzzle.decode(line)?.encode()

        // Assert
        #expect(encoded == line)
    }
}
