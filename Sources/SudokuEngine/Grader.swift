public enum Difficulty: Int, Sendable, CaseIterable, Comparable {
    case fast
    case beginner
    case easy
    case medium
    case hard
    case expert
    case evil

    public init?(name: String) {
        guard let match = Difficulty.allCases.first(where: { $0.name == name }) else {
            return nil
        }
        self = match
    }

    public var name: String {
        switch self {
        case .fast:
            "FAST"
        case .beginner:
            "BEGINNER"
        case .easy:
            "EASY"
        case .medium:
            "MEDIUM"
        case .hard:
            "HARD"
        case .expert:
            "EXPERT"
        case .evil:
            "EVIL"
        }
    }

    public var grid: Grid {
        self == .fast ? .fast : .standard
    }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public let classicLevels: [Difficulty] = [.fast, .easy, .medium, .hard, .expert]
public let killerLevels: [Difficulty] = Difficulty.allCases

public enum Technique: Int, Sendable, CaseIterable, Comparable {
    case nakedSingle
    case hiddenSingle
    case cageCombination
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case ruleOf45
    case nakedTriple
    case hiddenTriple
    case xWing
    case xyWing
    case nakedQuad
    case swordfish
    case xyzWing

    public var level: Difficulty {
        switch self {
        case .nakedSingle, .hiddenSingle, .cageCombination:
            .easy
        case .lockedCandidates, .nakedPair, .hiddenPair, .ruleOf45:
            .medium
        case .nakedTriple, .hiddenTriple, .xWing, .xyWing:
            .hard
        case .nakedQuad, .swordfish, .xyzWing:
            .expert
        }
    }

    public var weight: Int {
        switch self {
        case .nakedSingle:
            1
        case .hiddenSingle:
            2
        case .cageCombination:
            3
        case .lockedCandidates:
            8
        case .nakedPair:
            10
        case .hiddenPair, .ruleOf45:
            12
        case .nakedTriple:
            20
        case .hiddenTriple:
            25
        case .xWing:
            30
        case .xyWing:
            35
        case .nakedQuad:
            40
        case .swordfish:
            50
        case .xyzWing:
            55
        }
    }

    fileprivate var isKillerOnly: Bool {
        self == .cageCombination || self == .ruleOf45
    }

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Grade: Sendable, Equatable {
    public let level: Difficulty?
    public let hardest: Technique?
    public let score: Int
    public let solved: Bool

    public init(level: Difficulty?, hardest: Technique?, score: Int, solved: Bool) {
        self.level = level
        self.hardest = hardest
        self.score = score
        self.solved = solved
    }
}

private let effortPerExtraCombination = 4

func combinations<T>(_ items: [T], size: Int) -> [[T]] {
    if size == 0 {
        return [[]]
    }
    if items.count < size {
        return []
    }
    var result: [[T]] = []
    for index in 0...(items.count - size) {
        for rest in combinations(Array(items[(index + 1)...]), size: size - 1) {
            result.append([items[index]] + rest)
        }
    }
    return result
}

public struct Grader: Sendable {
    public private(set) var values: [Int]
    private let cages: [Cage]
    private let grid: Grid
    private let houseTotal: Int
    private let seen: [[Int]]
    private var cand: [Int]
    private var cageEffort = 0

    public init(givens: [Int], cages: [Cage] = []) {
        let grid = Grid.forCellCount(givens.count)
        self.cages = cages
        self.grid = grid
        houseTotal = grid.digits.reduce(0, +)
        values = givens
        var cageOf = [Int](repeating: noCage, count: grid.cells)
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                cageOf[cell] = index
            }
        }
        seen = (0..<grid.cells).map { cell in
            let cage = cageOf[cell]
            if cage == noCage {
                return grid.peers[cell]
            }
            return orderedUnique(grid.peers[cell] + cages[cage].cells).filter { $0 != cell }
        }
        cand = givens.map { $0 != 0 ? 0 : grid.allDigits }
        for cell in 0..<grid.cells where values[cell] != 0 {
            eliminateFromSeen(cell, values[cell])
        }
    }

    @discardableResult
    public mutating func grade(maxLevel: Difficulty = .expert) -> Grade {
        let techniques = Technique.allCases.filter { $0.level <= maxLevel && (!cages.isEmpty || !$0.isKillerOnly) }
        var hardest: Technique?
        var score = 0
        while values.contains(0) {
            if (0..<grid.cells).contains(where: { values[$0] == 0 && cand[$0] == 0 }) {
                break
            }
            cageEffort = 0
            var used: Technique?
            for technique in techniques where apply(technique) {
                used = technique
                break
            }
            guard let used else {
                break
            }
            if let current = hardest {
                hardest = max(current, used)
            } else {
                hardest = used
            }
            score += used.weight + cageEffort
        }
        let solved = !values.contains(0) && isValid()
        return Grade(level: solved ? (hardest?.level ?? .easy) : nil, hardest: hardest, score: score, solved: solved)
    }

    private mutating func apply(_ technique: Technique) -> Bool {
        switch technique {
        case .nakedSingle:
            nakedSingle()
        case .hiddenSingle:
            hiddenSingle()
        case .cageCombination:
            cageCombination()
        case .lockedCandidates:
            lockedCandidates()
        case .nakedPair:
            nakedSubset(2)
        case .hiddenPair:
            hiddenSubset(2)
        case .ruleOf45:
            ruleOf45()
        case .nakedTriple:
            nakedSubset(3)
        case .hiddenTriple:
            hiddenSubset(3)
        case .xWing:
            fish(2)
        case .xyWing:
            xyWing()
        case .nakedQuad:
            nakedSubset(4)
        case .swordfish:
            fish(3)
        case .xyzWing:
            xyzWing()
        }
    }

    private mutating func place(_ cell: Int, _ digit: Int) {
        values[cell] = digit
        cand[cell] = 0
        eliminateFromSeen(cell, digit)
    }

    private mutating func eliminateFromSeen(_ cell: Int, _ digit: Int) {
        let clear = ~digitBit(digit)
        for other in seen[cell] {
            cand[other] &= clear
        }
    }

    private mutating func eliminate(_ cell: Int, _ mask: Int) -> Bool {
        if cand[cell] & mask == 0 {
            return false
        }
        cand[cell] &= ~mask
        return true
    }

    private func isValid() -> Bool {
        grid.houses.allSatisfy { house in
            house.reduce(0) { $0 | digitBit(values[$1]) } == grid.allDigits
        }
            && cages.allSatisfy { cage in
                cage.cells.reduce(0) { $0 + values[$1] } == cage.sum
            }
    }

    private mutating func nakedSingle() -> Bool {
        for cell in 0..<grid.cells where values[cell] == 0 && cand[cell].nonzeroBitCount == 1 {
            place(cell, singleDigit(cand[cell]))
            return true
        }
        return false
    }

    private mutating func hiddenSingle() -> Bool {
        for house in grid.houses {
            for digit in grid.digits {
                let bit = digitBit(digit)
                var only = -1
                var count = 0
                for cell in house where cand[cell] & bit != 0 {
                    only = cell
                    count += 1
                }
                if count == 1 {
                    place(only, digit)
                    return true
                }
            }
        }
        return false
    }

    private mutating func cageCombination() -> Bool {
        for cage in cages where restrictCage(cage.cells, sum: cage.sum) {
            return true
        }
        return false
    }

    private mutating func lockedCandidates() -> Bool {
        var progress = false
        for digit in grid.digits {
            let bit = digitBit(digit)
            for box in grid.boxes {
                let cells = box.filter { cand[$0] & bit != 0 }
                if cells.isEmpty {
                    continue
                }
                if cells.allSatisfy({ grid.rowOf($0) == grid.rowOf(cells[0]) }) {
                    for cell in grid.rows[grid.rowOf(cells[0])] where !box.contains(cell) {
                        if eliminate(cell, bit) {
                            progress = true
                        }
                    }
                }
                if cells.allSatisfy({ grid.colOf($0) == grid.colOf(cells[0]) }) {
                    for cell in grid.cols[grid.colOf(cells[0])] where !box.contains(cell) {
                        if eliminate(cell, bit) {
                            progress = true
                        }
                    }
                }
                if progress {
                    return true
                }
            }
            for line in grid.rows + grid.cols {
                let cells = line.filter { cand[$0] & bit != 0 }
                if cells.isEmpty || !cells.allSatisfy({ grid.boxOf($0) == grid.boxOf(cells[0]) }) {
                    continue
                }
                for cell in grid.boxes[grid.boxOf(cells[0])] where !line.contains(cell) {
                    if eliminate(cell, bit) {
                        progress = true
                    }
                }
                if progress {
                    return true
                }
            }
        }
        return false
    }

    private mutating func nakedSubset(_ size: Int) -> Bool {
        for house in grid.houses {
            let open = house.filter { values[$0] == 0 && (2...size).contains(cand[$0].nonzeroBitCount) }
            for subset in combinations(open, size: size) {
                let union = subset.reduce(0) { $0 | cand[$1] }
                if union.nonzeroBitCount != size {
                    continue
                }
                var progress = false
                for cell in house where values[cell] == 0 && !subset.contains(cell) {
                    if eliminate(cell, union) {
                        progress = true
                    }
                }
                if progress {
                    return true
                }
            }
        }
        return false
    }

    private mutating func hiddenSubset(_ size: Int) -> Bool {
        for house in grid.houses {
            let digits = grid.digits.filter { digit in !house.contains { values[$0] == digit } }
            for subset in combinations(digits, size: size) {
                let mask = subset.reduce(0) { $0 | digitBit($1) }
                let cells = house.filter { cand[$0] & mask != 0 }
                if cells.count != size {
                    continue
                }
                var progress = false
                for cell in cells {
                    if eliminate(cell, grid.allDigits & ~mask) {
                        progress = true
                    }
                }
                if progress {
                    return true
                }
            }
        }
        return false
    }

    private mutating func fish(_ size: Int) -> Bool {
        for digit in grid.digits {
            let bit = digitBit(digit)
            for (base, cover) in [(grid.rows, grid.cols), (grid.cols, grid.rows)] {
                let positions = base.map { line in
                    line.indices.filter { cand[line[$0]] & bit != 0 }
                }
                let lines = base.indices.filter { (2...size).contains(positions[$0].count) }
                for subset in combinations(lines, size: size) {
                    let covered = orderedUnique(subset.flatMap { positions[$0] })
                    if covered.count != size {
                        continue
                    }
                    var progress = false
                    for coverIndex in covered {
                        for (baseIndex, cell) in cover[coverIndex].enumerated() where !subset.contains(baseIndex) {
                            if eliminate(cell, bit) {
                                progress = true
                            }
                        }
                    }
                    if progress {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && seen[a].contains(b)
    }

    private mutating func xyWing() -> Bool {
        let pairs = (0..<grid.cells).filter { values[$0] == 0 && cand[$0].nonzeroBitCount == 2 }
        for pivot in pairs {
            let wings = pairs.filter { sees(pivot, $0) && (cand[$0] & cand[pivot]).nonzeroBitCount == 1 }
            for wingPair in combinations(wings, size: 2) {
                let a = wingPair[0]
                let b = wingPair[1]
                let shared = cand[a] & cand[b]
                if shared.nonzeroBitCount != 1 || shared & cand[pivot] != 0 {
                    continue
                }
                if (cand[a] | cand[b]) & cand[pivot] != cand[pivot] {
                    continue
                }
                var progress = false
                for cell in 0..<grid.cells where cell != a && cell != b && sees(cell, a) && sees(cell, b) {
                    if eliminate(cell, shared) {
                        progress = true
                    }
                }
                if progress {
                    return true
                }
            }
        }
        return false
    }

    private mutating func xyzWing() -> Bool {
        for pivot in 0..<grid.cells {
            if values[pivot] != 0 || cand[pivot].nonzeroBitCount != 3 {
                continue
            }
            let wings = (0..<grid.cells).filter {
                values[$0] == 0 && cand[$0].nonzeroBitCount == 2 && cand[$0] & cand[pivot] == cand[$0]
                    && sees(pivot, $0)
            }
            for wingPair in combinations(wings, size: 2) {
                let a = wingPair[0]
                let b = wingPair[1]
                if cand[a] | cand[b] != cand[pivot] {
                    continue
                }
                let shared = cand[a] & cand[b]
                if shared.nonzeroBitCount != 1 {
                    continue
                }
                var progress = false
                for cell in 0..<grid.cells
                where cell != pivot && cell != a && cell != b && sees(cell, pivot) && sees(cell, a) && sees(cell, b) {
                    if eliminate(cell, shared) {
                        progress = true
                    }
                }
                if progress {
                    return true
                }
            }
        }
        return false
    }

    private func assign(
        index: Int,
        available: Int,
        open: [Int],
        chosen: inout [Int],
        possible: inout [Int]
    ) -> Bool {
        if index == open.count {
            for (position, digit) in chosen.enumerated() {
                possible[position] |= digitBit(digit)
            }
            return true
        }
        var found = false
        var mask = cand[open[index]] & available
        while mask != 0 {
            let bit = mask & -mask
            mask ^= bit
            chosen[index] = singleDigit(bit)
            if assign(index: index + 1, available: available ^ bit, open: open, chosen: &chosen, possible: &possible) {
                found = true
            }
        }
        return found
    }

    private mutating func restrictCage(_ cells: [Int], sum: Int) -> Bool {
        let open = cells.filter { values[$0] == 0 }
        if open.isEmpty {
            return false
        }
        let placed = cells.filter { values[$0] != 0 }
        let usedMask = placed.reduce(0) { $0 | digitBit(values[$1]) }
        let remaining = sum - placed.reduce(0) { $0 + values[$1] }
        var possible = [Int](repeating: 0, count: open.count)
        var fittingCombos = 0
        for combo in CageCombos.of(size: open.count, sum: remaining, allowedDigits: grid.allDigits)
        where combo & usedMask == 0 {
            var chosen = [Int](repeating: 0, count: open.count)
            if assign(index: 0, available: combo, open: open, chosen: &chosen, possible: &possible) {
                fittingCombos += 1
            }
        }
        var progress = false
        for (position, cell) in open.enumerated() {
            if eliminate(cell, grid.allDigits & ~possible[position]) {
                progress = true
            }
        }
        if progress {
            cageEffort += max(fittingCombos - 1, 0) * effortPerExtraCombination
        }
        return progress
    }

    private mutating func ruleOf45() -> Bool {
        for house in grid.houses {
            let houseCells = Set(house)
            let touching = cages.filter { cage in cage.cells.contains { houseCells.contains($0) } }
            let inside = touching.filter { cage in cage.cells.allSatisfy { houseCells.contains($0) } }
            let insideCells = Set(inside.flatMap(\.cells))
            let innies = house.filter { !insideCells.contains($0) }
            let insideSum = inside.reduce(0) { $0 + $1.sum }
            if (1...3).contains(innies.count) && restrictCage(innies, sum: houseTotal - insideSum) {
                return true
            }

            let touchingCells = touching.flatMap(\.cells)
            let outies = touchingCells.filter { !houseCells.contains($0) }
            let distinct = outies.allSatisfy { a in outies.allSatisfy { b in a == b || sees(a, b) } }
            let coversHouse = houseCells.isSubset(of: touchingCells)
            if (1...3).contains(outies.count) && distinct && coversHouse {
                let touchingSum = touching.reduce(0) { $0 + $1.sum }
                if restrictCage(outies, sum: touchingSum - houseTotal) {
                    return true
                }
            }
        }
        return false
    }
}
