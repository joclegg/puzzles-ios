import PuzzlesCore

public enum CageCombos {
    private static let maxSize = 9
    private static let maxSum = 45

    private static let table: [[[Int]]] = {
        var result = [[[Int]]](
            repeating: [[Int]](repeating: [], count: maxSum + 1),
            count: maxSize + 1
        )
        for mask in stride(from: 0, to: 1024, by: 2) {
            result[mask.nonzeroBitCount][digitsOf(mask).reduce(0, +)].append(mask)
        }
        return result
    }()

    private static let fastTable = restricted(to: Grid.fast.allDigits)

    public static func of(size: Int, sum: Int, allowedDigits: Int = Grid.standard.allDigits) -> [Int] {
        if !(0...maxSize).contains(size) || !(0...maxSum).contains(sum) {
            return []
        }
        if allowedDigits == Grid.standard.allDigits {
            return table[size][sum]
        }
        if allowedDigits == Grid.fast.allDigits {
            return fastTable[size][sum]
        }
        return table[size][sum].filter { $0 & allowedDigits == $0 }
    }

    private static func restricted(to allowedDigits: Int) -> [[[Int]]] {
        table.map { sums in
            sums.map { combos in
                combos.filter { $0 & allowedDigits == $0 }
            }
        }
    }
}

public struct Solver: Sendable {
    public private(set) var consistent = false
    private let grid: Grid
    private var values: [Int]
    private var rowUsed: [Int]
    private var colUsed: [Int]
    private var boxUsed: [Int]
    private var cageOf: [Int]
    private var cageUsed: [Int]
    private var cageRemaining: [Int]
    private var cageEmpty: [Int]
    private var stepsLeft = Int64.max

    public init(givens: [Int], cages: [Cage] = []) {
        let grid = Grid.forCellCount(givens.count)
        self.grid = grid
        values = [Int](repeating: 0, count: grid.cells)
        rowUsed = [Int](repeating: 0, count: grid.size)
        colUsed = [Int](repeating: 0, count: grid.size)
        boxUsed = [Int](repeating: 0, count: grid.size)
        cageOf = [Int](repeating: noCage, count: grid.cells)
        cageUsed = [Int](repeating: 0, count: cages.count)
        cageRemaining = cages.map(\.sum)
        cageEmpty = cages.map(\.cells.count)
        var ok = true
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                if cageOf[cell] != noCage {
                    ok = false
                }
                cageOf[cell] = index
            }
        }
        for cell in 0..<grid.cells {
            let digit = givens[cell]
            if digit == 0 {
                continue
            }
            if candidates(cell) & digitBit(digit) == 0 {
                ok = false
            }
            place(cell, digit)
        }
        consistent =
            ok
            && cages.indices.allSatisfy {
                cageRemaining[$0] >= 0 && (cageEmpty[$0] > 0 || cageRemaining[$0] == 0)
            }
    }

    public static func randomGrid(random: inout XorWowRandom, grid: Grid = .standard) -> [Int] {
        guard let solved = Solver(givens: grid.emptyValues()).solve(random: &random) else {
            preconditionFailure("An empty grid always has a solution")
        }
        return solved
    }

    public func countSolutions(limit: Int = 2) -> Int {
        guard let count = countSolutionsWithin(limit: limit, maxSteps: .max) else {
            preconditionFailure("An unlimited search cannot run out of steps")
        }
        return count
    }

    public func countSolutionsWithin(limit: Int, maxSteps: Int64) -> Int? {
        if !consistent {
            return 0
        }
        var solver = self
        solver.stepsLeft = maxSteps
        var count = 0
        var noRandom: XorWowRandom?
        _ = solver.search(random: &noRandom) { _ in
            count += 1
            return count >= limit
        }
        return solver.stepsLeft < 0 ? nil : count
    }

    public func solve() -> [Int]? {
        var noRandom: XorWowRandom?
        return firstSolution(random: &noRandom)
    }

    public func solve(random: inout XorWowRandom) -> [Int]? {
        var seeded: XorWowRandom? = random
        let result = firstSolution(random: &seeded)
        if let seeded {
            random = seeded
        }
        return result
    }

    private func firstSolution(random: inout XorWowRandom?) -> [Int]? {
        if !consistent {
            return nil
        }
        var solver = self
        var result: [Int]?
        _ = solver.search(random: &random) { solved in
            result = solved
            return true
        }
        return result
    }

    private mutating func search(random: inout XorWowRandom?, onSolution: ([Int]) -> Bool) -> Bool {
        stepsLeft -= 1
        if stepsLeft < 0 {
            return true
        }
        var best = -1
        var bestMask = 0
        var bestCount = 10
        for cell in 0..<grid.cells {
            if values[cell] != 0 {
                continue
            }
            let mask = candidates(cell)
            let count = mask.nonzeroBitCount
            if count == 0 {
                return false
            }
            if count < bestCount {
                best = cell
                bestMask = mask
                bestCount = count
                if count == 1 {
                    break
                }
            }
        }
        if best == -1 {
            return onSolution(values)
        }
        var digits = digitsOf(bestMask)
        if random != nil {
            digits = digits.shuffled(using: &random!)
        }
        for digit in digits {
            place(best, digit)
            let stop = search(random: &random, onSolution: onSolution)
            unplace(best, digit)
            if stop {
                return true
            }
        }
        return false
    }

    private func candidates(_ cell: Int) -> Int {
        let used = rowUsed[grid.rowOf(cell)] | colUsed[grid.colOf(cell)] | boxUsed[grid.boxOf(cell)]
        var mask = grid.allDigits & ~used
        let cage = cageOf[cell]
        if cage != noCage {
            var allowed = 0
            for combo in CageCombos.of(size: cageEmpty[cage], sum: cageRemaining[cage], allowedDigits: grid.allDigits)
            where combo & cageUsed[cage] == 0 {
                allowed |= combo
            }
            mask &= allowed
        }
        return mask
    }

    private mutating func place(_ cell: Int, _ digit: Int) {
        let bit = digitBit(digit)
        values[cell] = digit
        rowUsed[grid.rowOf(cell)] |= bit
        colUsed[grid.colOf(cell)] |= bit
        boxUsed[grid.boxOf(cell)] |= bit
        let cage = cageOf[cell]
        if cage != noCage {
            cageUsed[cage] |= bit
            cageRemaining[cage] -= digit
            cageEmpty[cage] -= 1
        }
    }

    private mutating func unplace(_ cell: Int, _ digit: Int) {
        let bit = ~digitBit(digit)
        values[cell] = 0
        rowUsed[grid.rowOf(cell)] &= bit
        colUsed[grid.colOf(cell)] &= bit
        boxUsed[grid.boxOf(cell)] &= bit
        let cage = cageOf[cell]
        if cage != noCage {
            cageUsed[cage] &= bit
            cageRemaining[cage] += digit
            cageEmpty[cage] += 1
        }
    }
}
