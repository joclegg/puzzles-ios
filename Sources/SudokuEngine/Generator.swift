import PuzzlesCore

public struct GeneratedPuzzle: Sendable, Equatable {
    public let puzzle: Puzzle
    public let grade: Grade

    public init(puzzle: Puzzle, grade: Grade) {
        self.puzzle = puzzle
        self.grade = grade
    }
}

public enum Generator {
    private static let classicFloor: [Difficulty: Int] = [
        .fast: 12, .easy: 36, .medium: 30, .hard: 25, .expert: 22,
    ]
    private static let killerFloor: [Difficulty: Int] = [
        .fast: 4, .beginner: 32, .easy: 24, .medium: 16, .hard: 8, .expert: 2, .evil: 0,
    ]
    private static let rareSinglesWeight = 1
    private static let maxMergedCage = 6
    private static let layoutTries = 12

    public static let killerScoreBands: [Difficulty: Range<Int>] = [
        .beginner: 0..<90,
        .easy: 90..<140,
        .medium: 140..<300,
        .hard: 300..<600,
        .expert: 600..<900,
        .evil: 900..<Int(Int32.max),
    ]

    private struct CageProfile: Sendable {
        let sizeWeights: [Int]
        let oneWaySumPreference: Int
    }

    private static let cageProfiles: [Difficulty: CageProfile] = [
        .fast: CageProfile(sizeWeights: [4, 35, 40, 16, 5], oneWaySumPreference: 0),
        .beginner: CageProfile(sizeWeights: [20, 60, 18, 2, 0], oneWaySumPreference: 1),
        .easy: CageProfile(sizeWeights: [12, 58, 25, 5, 0], oneWaySumPreference: 1),
        .medium: CageProfile(sizeWeights: [5, 45, 35, 13, 2], oneWaySumPreference: 0),
        .hard: CageProfile(sizeWeights: [1, 30, 40, 22, 7], oneWaySumPreference: -1),
        .expert: CageProfile(sizeWeights: [0, 22, 40, 26, 12], oneWaySumPreference: -1),
        .evil: CageProfile(sizeWeights: [0, 12, 38, 30, 20], oneWaySumPreference: -1),
    ]

    public static func classic(
        target: Difficulty,
        random: inout XorWowRandom,
        maxAttempts: Int = 50
    ) -> GeneratedPuzzle? {
        for _ in 0..<maxAttempts {
            let grid = target.grid
            let solution = Solver.randomGrid(random: &random, grid: grid)
            let pairs = (0..<(grid.cells + 1) / 2).map { orderedUnique([$0, grid.cells - 1 - $0]) }
                .shuffled(using: &random)
            guard let floor = classicFloor[target] else {
                preconditionFailure("\(target) is not a classic level")
            }
            if let made = dig(solution: solution, cages: [], groups: pairs, target: target, floor: floor) {
                return made
            }
        }
        return nil
    }

    public static func killer(
        target: Difficulty,
        random: inout XorWowRandom,
        maxAttempts: Int = 50,
        anyScore: Bool = false
    ) -> GeneratedPuzzle? {
        for _ in 0..<maxAttempts {
            let solution = Solver.randomGrid(random: &random, grid: target.grid)
            let cages = cagesFor(target: target, solution: solution, random: &random)
            let cells = solution.indices.map { [$0] }.shuffled(using: &random)
            guard let floor = killerFloor[target] else {
                preconditionFailure("\(target) is not a killer level")
            }
            let band = anyScore ? nil : killerScoreBands[target]
            if let made = dig(
                solution: solution,
                cages: cages,
                groups: cells,
                target: target,
                floor: floor,
                killerScoreBand: band
            ) {
                return made
            }
        }
        return nil
    }

    private static func dig(
        solution: [Int],
        cages: [Cage],
        groups: [[Int]],
        target: Difficulty,
        floor: Int,
        killerScoreBand: Range<Int>? = nil
    ) -> GeneratedPuzzle? {
        var givens = solution
        var count = solution.count
        for group in groups {
            if count - group.count < floor {
                continue
            }
            for cell in group {
                givens[cell] = 0
            }
            var trial = Grader(givens: givens, cages: cages)
            if trial.grade(maxLevel: max(target, .easy)).solved {
                count -= group.count
            } else {
                for cell in group {
                    givens[cell] = solution[cell]
                }
            }
        }
        var grader = Grader(givens: givens, cages: cages)
        let grade = grader.grade()
        let accepted: Bool
        if !cages.isEmpty {
            accepted = grade.solved && (killerScoreBand?.contains(grade.score) ?? true)
        } else if target == .fast {
            accepted = grade.solved
        } else {
            accepted = grade.level == target
        }
        return accepted ? GeneratedPuzzle(puzzle: Puzzle(givens: givens, solution: solution, cages: cages), grade: grade) : nil
    }

    public static func cagesFor(target: Difficulty, solution: [Int], random: inout XorWowRandom) -> [Cage] {
        guard let profile = cageProfiles[target] else {
            preconditionFailure("\(target) has no cage profile")
        }
        let grid = Grid.forCellCount(solution.count)
        var best: [Cage] = []
        var bestScore = -Double.infinity
        for _ in 0..<layoutTries {
            let layout = randomCages(solution: solution, random: &random, sizeWeights: profile.sizeWeights)
            let score = Double(profile.oneWaySumPreference) * oneWaySumShare(cages: layout, grid: grid)
            if score > bestScore {
                best = layout
                bestScore = score
            }
        }
        return best
    }

    public static func randomCages(
        solution: [Int],
        random: inout XorWowRandom,
        sizeWeights: [Int]? = nil
    ) -> [Cage] {
        guard let weights = sizeWeights ?? cageProfiles[.medium]?.sizeWeights else {
            preconditionFailure("The medium level always has a cage profile")
        }
        let grid = Grid.forCellCount(solution.count)
        var owner = [Int](repeating: noCage, count: solution.count)
        var cages: [[Int]] = []
        for seed in Array(solution.indices).shuffled(using: &random) {
            if owner[seed] != noCage {
                continue
            }
            let target = pickSize(sizeWeights: weights, random: &random)
            var cage = [seed]
            owner[seed] = cages.count
            while cage.count < target {
                let options = orderedUnique(cage.flatMap { grid.neighbours($0) }).filter { option in
                    owner[option] == noCage && !cage.contains { solution[$0] == solution[option] }
                }
                guard let next = pick(options, random: &random) else {
                    break
                }
                owner[next] = cages.count
                cage.append(next)
            }
            cages.append(cage)
        }
        if weights[0] <= rareSinglesWeight {
            mergeOrphans(cages: &cages, owner: &owner, solution: solution, random: &random)
        }
        return cages.filter { !$0.isEmpty }.map { cells in
            Cage(cells: cells.sorted(), sum: cells.reduce(0) { $0 + solution[$1] })
        }
    }

    private static func mergeOrphans(
        cages: inout [[Int]],
        owner: inout [Int],
        solution: [Int],
        random: inout XorWowRandom
    ) {
        let grid = Grid.forCellCount(solution.count)
        for orphan in cages.indices {
            if cages[orphan].count != 1 {
                continue
            }
            let cell = cages[orphan][0]
            let snapshot = cages
            let homes = orderedUnique(grid.neighbours(cell).map { owner[$0] }).filter { other in
                snapshot[other].count < maxMergedCage && !snapshot[other].contains { solution[$0] == solution[cell] }
            }
            guard let home = pick(homes, random: &random) else {
                continue
            }
            cages[home].append(cell)
            owner[cell] = home
            cages[orphan].removeAll()
        }
    }

    public static func oneWaySumShare(cages: [Cage], grid: Grid = .standard) -> Double {
        let oneWay = cages.count { cage in
            cage.cells.count > 1
                && CageCombos.of(size: cage.cells.count, sum: cage.sum, allowedDigits: grid.allDigits).count == 1
        }
        return Double(oneWay) / Double(cages.count)
    }

    private static func pick(_ items: [Int], random: inout XorWowRandom) -> Int? {
        items.isEmpty ? nil : items[random.nextInt(below: items.count)]
    }

    private static func pickSize(sizeWeights: [Int], random: inout XorWowRandom) -> Int {
        var roll = random.nextInt(below: sizeWeights.reduce(0, +))
        for (index, weight) in sizeWeights.enumerated() {
            if roll < weight {
                return index + 1
            }
            roll -= weight
        }
        return 1
    }
}
