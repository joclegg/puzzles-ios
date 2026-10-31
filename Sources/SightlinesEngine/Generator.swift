import PuzzlesCore

public enum Generator {
    private static let redChance = 0.3
    private static let dailySeedSpread: Int64 = 7_919

    public static func dailySeed(date: CalendarDay, size: Int) -> Int64 {
        Int64(date.daysSinceEpoch) * dailySeedSpread + Int64(size)
    }

    public static func daily(date: CalendarDay, size: Int) -> Puzzle {
        generate(size: size, seed: dailySeed(date: date, size: size))
    }

    public static func generate(size: Int, seed: Int64) -> Puzzle {
        var random = XorWowRandom(seed: seed)
        let solution = makeSolution(size: size, random: &random)
        var numbers: [Int: Int] = [:]
        var walls = Set<Int>()
        for cell in solution.dots.indices {
            if solution.dots[cell] == .blue {
                numbers[cell] = solution.seen(cell)
            } else if solution.dots[cell] == .red {
                walls.insert(cell)
            }
        }
        for cell in Array(solution.dots.indices).shuffled(using: &random) {
            var fewerNumbers = numbers
            fewerNumbers[cell] = nil
            var fewerWalls = walls
            fewerWalls.remove(cell)
            let candidate = Puzzle(solution: solution, numbers: fewerNumbers, walls: fewerWalls)
            if Solver.solveLogically(candidate.givens, numbers: fewerNumbers) == solution {
                numbers = fewerNumbers
                walls = fewerWalls
            }
        }
        return Puzzle(solution: solution, numbers: numbers, walls: walls)
    }

    private static func makeSolution(size: Int, random: inout XorWowRandom) -> Grid {
        var dots: [Dot] = []
        for _ in 0..<(size * size) {
            dots.append(random.nextDouble() < redChance ? .red : .blue)
        }
        var grid = Grid(size: size, dots: dots)
        while true {
            let current = grid
            let blues = current.dots.indices.filter { current.dots[$0] == .blue }
            if let lonely = blues.first(where: { current.seen($0) == 0 }) {
                grid = current.with(cell: lonely, dot: .red)
                continue
            }
            guard let crowded = blues.first(where: { current.seen($0) > size }) else {
                return current
            }
            let inView = Direction.allCases.flatMap { direction in
                current.ray(crowded, direction: direction).prefix(current.seen(crowded, direction: direction))
            }
            grid = current.with(cell: inView[random.nextInt(below: inView.count)], dot: .red)
        }
    }
}
