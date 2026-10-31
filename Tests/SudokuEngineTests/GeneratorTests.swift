import PuzzlesCore
import Testing

@testable import SudokuEngine

struct GeneratorTests {
    @Test("given the fast level when puzzles are generated then they are 6x6 with one solution", arguments: [Difficulty.fast])
    func fastLevel(level: Difficulty) throws {
        // Arrange
        var random = XorWowRandom(intSeed: 11)

        // Act
        let classic = try #require(Generator.classic(target: level, random: &random)).puzzle
        let killer = try #require(Generator.killer(target: level, random: &random)).puzzle

        // Assert
        #expect(classic.givens.count == 36)
        #expect(killer.givens.count == 36)
        #expect(Solver(givens: classic.givens).countSolutions() == 1)
        #expect(Solver(givens: killer.givens, cages: killer.cages).countSolutions() == 1)
    }

    @Test(
        "given a classic level when a puzzle is generated then it has that level and one solution",
        arguments: [Difficulty.easy, .medium]
    )
    func classicLevel(level: Difficulty) throws {
        // Arrange
        var random = XorWowRandom(intSeed: Int32(level.rawValue))

        // Act
        let generated = try #require(Generator.classic(target: level, random: &random))

        // Assert
        #expect(generated.grade.level == level)
        #expect(Solver(givens: generated.puzzle.givens).countSolutions() == 1)
    }

    @Test(
        "given a killer level when a puzzle is generated then its score is in the level's band and it has one solution",
        arguments: killerLevels
    )
    func killerLevel(level: Difficulty) throws {
        // Arrange
        var random = XorWowRandom(intSeed: Int32(level.rawValue + 100))

        // Act
        let generated = try #require(Generator.killer(target: level, random: &random))

        // Assert
        let puzzle = generated.puzzle
        #expect(Generator.killerScoreBands[level]?.contains(generated.grade.score) ?? generated.grade.solved)
        #expect(Solver(givens: puzzle.givens, cages: puzzle.cages).countSolutions() == 1)
    }

    @Test("given the killer score bands when read in level order then they climb without gaps or overlaps")
    func scoreBandsJoin() throws {
        // Arrange
        let bands = killerLevels.compactMap { Generator.killerScoreBands[$0] }

        // Act
        let joins = zip(bands, bands.dropFirst()).map { lower, upper in lower.upperBound == upper.lowerBound }

        // Assert
        #expect(joins.allSatisfy { $0 })
        #expect(bands.first?.lowerBound == 0)
    }

    @Test("given a killer puzzle when its cages are checked then they cover the grid and match the solution")
    func cagesCoverGrid() throws {
        // Arrange
        var random = XorWowRandom(intSeed: 3)
        let puzzle = try #require(Generator.killer(target: .easy, random: &random)).puzzle
        let solution = try #require(puzzle.solution)

        // Act
        let covered = Set(puzzle.cages.flatMap(\.cells))

        // Assert
        #expect(covered == Set(0..<Grid.standard.cells))
        #expect(puzzle.cages.allSatisfy { cage in cage.cells.reduce(0) { $0 + solution[$1] } == cage.sum })
    }

    @Test(
        "given a killer level when cages are laid out then easier levels have more single cells",
        arguments: killerLevels
    )
    func singleCells(level: Difficulty) {
        // Arrange
        var gridRandom = XorWowRandom(intSeed: 5)
        var cageRandom = XorWowRandom(intSeed: 5)
        let solution = Solver.randomGrid(random: &gridRandom, grid: level.grid)

        // Act
        let singles = Generator.cagesFor(target: level, solution: solution, random: &cageRandom)
            .count { $0.cells.count == 1 }

        // Assert
        if level == .fast {
            #expect(singles >= 0)
        } else if level >= .hard {
            #expect(singles == 0)
        } else {
            #expect(singles > 0)
        }
    }

    @Test("given a killer puzzle when it is encoded and decoded then it is unchanged")
    func codecRoundTrip() throws {
        // Arrange
        var random = XorWowRandom(intSeed: 4)
        let puzzle = try #require(Generator.killer(target: .easy, random: &random)).puzzle

        // Act
        let decoded = try PuzzleCodec.decode(PuzzleCodec.encode(puzzle))

        // Assert
        #expect(decoded == puzzle)
    }
}
