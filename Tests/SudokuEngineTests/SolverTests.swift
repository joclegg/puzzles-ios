import PuzzlesCore
import Testing

@testable import SudokuEngine

struct SolverTests {
    @Test("given a classic puzzle when it is solved then the known solution is found")
    func solvesKnownPuzzle() {
        // Arrange
        let solver = Solver(givens: digits(easyGivens))

        // Act
        let solution = solver.solve()

        // Assert
        #expect(solution == digits(easySolution))
    }

    @Test(
        "given some givens when solutions are counted up to two then unique, several and clashing grids are told apart",
        arguments: [
            ("530070000600195000098000060800060003400803001700020006060000280000419005000080079", 1),
            ("500000000000000000000000000000000000000000000000000000000000000000000000000000000", 2),
            ("550000000000000000000000000000000000000000000000000000000000000000000000000000000", 0),
        ]
    )
    func countsSolutions(givens: String, expectedCount: Int) {
        // Arrange
        let solver = Solver(givens: digits(givens))

        // Act
        let count = solver.countSolutions(limit: 2)

        // Assert
        #expect(count == expectedCount)
    }

    @Test("given clashing givens when the solver is created then it is inconsistent and has no solution")
    func clashingGivens() {
        // Arrange
        let clashing = (0..<Grid.standard.cells).map { $0 == 0 || $0 == 1 ? 5 : 0 }

        // Act
        let solver = Solver(givens: clashing)

        // Assert
        #expect(!solver.consistent)
        #expect(solver.solve() == nil)
    }

    @Test("given a seed when a random grid is made then it is a valid full grid", arguments: [Int32(1), 2, 3])
    func randomGridIsValid(seed: Int32) {
        // Arrange
        var random = XorWowRandom(intSeed: seed)

        // Act
        let grid = Solver.randomGrid(random: &random)

        // Assert
        #expect(conflicts(values: grid).isEmpty)
    }

    @Test("given random killer cages when the empty grid is solved then every cage adds up")
    func killerCagesAddUp() throws {
        // Arrange
        var random = XorWowRandom(intSeed: 7)
        let cages = Generator.randomCages(solution: digits(easySolution), random: &random)

        // Act
        let solved = try #require(Solver(givens: Grid.standard.emptyValues(), cages: cages).solve())

        // Assert
        #expect(cages.allSatisfy { cage in cage.cells.reduce(0) { $0 + solved[$1] } == cage.sum })
        #expect(conflicts(values: solved, cages: cages).isEmpty)
    }

    @Test(
        "given a cage size and sum when combinations are listed then the count of digit sets is right",
        arguments: [(2, 3, 1), (2, 17, 1), (2, 10, 4), (2, 2, 0), (9, 45, 1)]
    )
    func cageCombinationCount(size: Int, sum: Int, expected: Int) {
        // Act
        let combinations = CageCombos.of(size: size, sum: sum)

        // Assert
        #expect(combinations.count == expected)
    }

    @Test(
        "given a step budget when solutions are counted then the solver gives up only if the budget runs out",
        arguments: [(Int64(10), true), (Int64(1_000_000), false)]
    )
    func stepBudget(maxSteps: Int64, expectGiveUp: Bool) {
        // Arrange
        let solver = Solver(givens: Grid.standard.emptyValues())

        // Act
        let count = solver.countSolutionsWithin(limit: 2, maxSteps: maxSteps)

        // Assert
        #expect(count == (expectGiveUp ? nil : 2))
    }
}
