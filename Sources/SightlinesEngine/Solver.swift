public enum Reason: Sendable, Equatable, CaseIterable {
    case satisfied
    case tooMany
    case needs
    case alone
}

public struct Deduction: Sendable, Equatable {
    public let cells: [Int]
    public let dot: Dot
    public let reason: Reason
    public let source: Int

    public init(cells: [Int], dot: Dot, reason: Reason, source: Int) {
        self.cells = cells
        self.dot = dot
        self.reason = reason
        self.source = source
    }
}

public enum Solver {
    public static func next(_ grid: Grid, numbers: [Int: Int]) -> Deduction? {
        let numbered = numbers.keys.sorted().map { (cell: $0, number: numbers[$0, default: 0]) }
        let unnumbered = grid.dots.indices
            .filter { grid.dots[$0] == .blue && numbers[$0] == nil }
            .map { (cell: $0, number: 1) }
        let targets = numbered + unnumbered
        for target in targets {
            if let deduction = satisfied(grid, target.cell, target.number, exact: numbers[target.cell] != nil) {
                return deduction
            }
        }
        for target in targets {
            if let deduction = tooMany(grid, target.cell, target.number, exact: numbers[target.cell] != nil) {
                return deduction
            }
        }
        for target in targets {
            if let deduction = needs(grid, target.cell, target.number) {
                return deduction
            }
        }
        return alone(grid)
    }

    public static func solveLogically(_ start: Grid, numbers: [Int: Int]) -> Grid? {
        var grid = start
        while !grid.isFull {
            guard let deduction = next(grid, numbers: numbers) else {
                return nil
            }
            for cell in deduction.cells {
                grid = grid.with(cell: cell, dot: deduction.dot)
            }
        }
        return grid
    }

    private static func closingEnd(_ grid: Grid, _ cell: Int, _ direction: Direction) -> Int? {
        let end = grid.ray(cell, direction: direction).dropFirst(grid.seen(cell, direction: direction)).first
        guard let end, grid.dots[end] == .empty else {
            return nil
        }
        return end
    }

    private static func satisfied(_ grid: Grid, _ cell: Int, _ number: Int, exact: Bool) -> Deduction? {
        guard exact, grid.seen(cell) == number else {
            return nil
        }
        let ends = Direction.allCases.compactMap { closingEnd(grid, cell, $0) }
        if ends.isEmpty {
            return nil
        }
        return Deduction(cells: ends, dot: .red, reason: .satisfied, source: cell)
    }

    private static func tooMany(_ grid: Grid, _ cell: Int, _ number: Int, exact: Bool) -> Deduction? {
        guard exact else {
            return nil
        }
        let seen = grid.seen(cell)
        for direction in Direction.allCases {
            guard let end = closingEnd(grid, cell, direction) else {
                continue
            }
            let beyond = grid.ray(end, direction: direction).prefix { grid.dots[$0] == .blue }.count
            if seen + 1 + beyond > number {
                return Deduction(cells: [end], dot: .red, reason: .tooMany, source: cell)
            }
        }
        return nil
    }

    private static func needs(_ grid: Grid, _ cell: Int, _ number: Int) -> Deduction? {
        for direction in Direction.allCases {
            let others = Direction.allCases
                .filter { $0 != direction }
                .reduce(0) { $0 + grid.reach(cell, direction: $1) }
            if number - others > grid.seen(cell, direction: direction),
                let end = closingEnd(grid, cell, direction)
            {
                return Deduction(cells: [end], dot: .blue, reason: .needs, source: cell)
            }
        }
        return nil
    }

    private static func alone(_ grid: Grid) -> Deduction? {
        let cell = grid.dots.indices.first { cell in
            grid.dots[cell] == .empty && Direction.allCases.allSatisfy { grid.reach(cell, direction: $0) == 0 }
        }
        guard let cell else {
            return nil
        }
        return Deduction(cells: [cell], dot: .red, reason: .alone, source: cell)
    }
}
