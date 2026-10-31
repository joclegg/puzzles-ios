public enum CageProblem: Sendable, Equatable {
    case empty
    case notConnected
    case impossibleSum
}

private let maxSumDigits = 2

public struct CageBuilder: Sendable, Equatable {
    public var cages: [Cage]
    public var selection: [Int]
    public var sumInput: String
    public var editingCage: Int?
    public var nextDigitReplacesSum: Bool
    public var grid: Grid

    public init(
        cages: [Cage] = [],
        selection: [Int] = [],
        sumInput: String = "",
        editingCage: Int? = nil,
        nextDigitReplacesSum: Bool = false,
        grid: Grid = .standard
    ) {
        self.cages = cages
        self.selection = selection
        self.sumInput = sumInput
        self.editingCage = editingCage
        self.nextDigitReplacesSum = nextDigitReplacesSum
        self.grid = grid
    }

    public var cageOwner: [Int] {
        var owner = [Int](repeating: noCage, count: grid.cells)
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                owner[cell] = index
            }
        }
        return owner
    }

    public func tapCell(_ cell: Int) -> CageBuilder {
        let owner = cageOwner[cell]
        var next = self
        if selection.contains(cell) {
            next.selection = selection.filter { $0 != cell }
            return next
        }
        if owner != noCage && owner != editingCage {
            return selectCage(owner)
        }
        if selection.contains(where: { grid.isOrthogonalNeighbour($0, cell) }) {
            next.selection = selection + [cell]
            return next
        }
        return CageBuilder(cages: cages, selection: [cell], grid: grid)
    }

    public func typeDigit(_ digit: Int) -> CageBuilder {
        var next = self
        if nextDigitReplacesSum || sumInput.count >= maxSumDigits {
            next.sumInput = String(digit)
        } else {
            next.sumInput = sumInput + String(digit)
        }
        next.nextDigitReplacesSum = false
        return next
    }

    public func problem() -> CageProblem? {
        guard !selection.isEmpty, let sum = Int(sumInput) else {
            return .empty
        }
        if !grid.isConnected(selection) {
            return .notConnected
        }
        if CageCombos.of(size: selection.count, sum: sum, allowedDigits: grid.allDigits).isEmpty {
            return .impossibleSum
        }
        return nil
    }

    public func confirm() -> CageBuilder {
        guard problem() == nil, let sum = Int(sumInput) else {
            var next = self
            next.nextDigitReplacesSum = true
            return next
        }
        return CageBuilder(cages: keptCages() + [Cage(cells: selection.sorted(), sum: sum)], grid: grid)
    }

    public func deleteSelection() -> CageBuilder {
        CageBuilder(cages: keptCages(), grid: grid)
    }

    private func keptCages() -> [Cage] {
        cages.indices.filter { $0 != editingCage }.map { cages[$0] }
    }

    private func selectCage(_ index: Int) -> CageBuilder {
        var next = self
        next.selection = cages[index].cells
        next.sumInput = String(cages[index].sum)
        next.editingCage = index
        next.nextDigitReplacesSum = true
        return next
    }
}

extension Grid {
    public func isOrthogonalNeighbour(_ a: Int, _ b: Int) -> Bool {
        neighbours(a).contains(b)
    }

    public func isConnected(_ cells: [Int]) -> Bool {
        guard let first = cells.first else {
            return false
        }
        var reached: Set<Int> = [first]
        var frontier = [first]
        while let cell = frontier.popLast() {
            for next in cells where !reached.contains(next) && isOrthogonalNeighbour(cell, next) {
                reached.insert(next)
                frontier.append(next)
            }
        }
        return reached.count == cells.count
    }
}
