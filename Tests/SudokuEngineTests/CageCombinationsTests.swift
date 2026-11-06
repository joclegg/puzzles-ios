import PuzzlesCore
import Testing

@testable import SudokuEngine

struct CageCombinationsTests {
    private func killer(_ grid: Grid, _ cage: Cage, selected: Int, placed: [Int: Int] = [:]) -> GameState {
        var game = GameState(puzzle: Puzzle(givens: [Int](repeating: 0, count: grid.cells), solution: nil, cages: [cage]))
        for (cell, digit) in placed {
            game.values[cell] = digit
        }
        game.selected = selected
        return game
    }

    private func digits(_ line: CombinationLine?) -> [String]? {
        line?.sets.map { $0.map { String($0.digit) }.joined(separator: " ") }
    }

    @Test(
        "given a selected cell in an empty cage when its combinations are listed then every set of different digits that adds up is there",
        arguments: [
            (2, 10, ["1 9", "2 8", "3 7", "4 6"]),
            (2, 17, ["8 9"]),
            (3, 6, ["1 2 3"]),
        ]
    )
    func combinations(length: Int, sum: Int, expected: [String]) {
        // Arrange
        let game = killer(.standard, Cage(cells: Array(0..<length), sum: sum), selected: 0)

        // Act
        let line = game.cageCombinationLine(order: .increasing)

        // Assert
        #expect(Set(digits(line) ?? []) == Set(expected))
        #expect(line?.header == "Cage \(sum) in \(length): ")
    }

    @Test("given a cage with a placed digit when its combinations are listed then only those holding that digit remain")
    func placedDigit() {
        // Arrange
        let game = killer(.standard, Cage(cells: [0, 1], sum: 10), selected: 1, placed: [0: 3])

        // Act
        let line = game.cageCombinationLine(order: .increasing)

        // Assert
        #expect(line?.sets == [[CombinationDigit(digit: 3, placed: true), CombinationDigit(digit: 7, placed: false)]])
    }

    @Test("given a six by six grid when a cage's combinations are listed then digits above six are left out")
    func smallGrid() {
        // Arrange
        let game = killer(.fast, Cage(cells: [0, 1], sum: 11), selected: 0)

        // Act
        let line = game.cageCombinationLine(order: .increasing)

        // Assert
        #expect(digits(line) == ["5 6"])
    }

    @Test("given a selected cell outside every cage when combinations are listed then there are none")
    func outsideCage() {
        // Arrange
        let game = killer(.standard, Cage(cells: [0, 1], sum: 10), selected: 5)

        // Act
        let line = game.cageCombinationLine(order: .increasing)

        // Assert
        #expect(line == nil)
    }
}
