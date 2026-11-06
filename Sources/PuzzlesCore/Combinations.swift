public struct CombinationDigit: Sendable, Equatable {
    public let digit: Int
    public let placed: Bool

    public init(digit: Int, placed: Bool) {
        self.digit = digit
        self.placed = placed
    }
}

public enum CombinationOrder: String, Sendable, CaseIterable {
    case increasing
    case decreasing
}

public struct CombinationLine: Sendable, Equatable {
    public let header: String
    public let sets: [[CombinationDigit]]

    public init(header: String, sets: [[CombinationDigit]]) {
        self.header = header
        self.sets = sets
    }
}

public enum Combinations {
    private static let sumsPerLength = 100
    private static let maxDigit = 9

    private static let byRun: [Int: [Int]] = {
        var groups: [Int: [Int]] = [:]
        for mask in 1..<(1 << maxDigit) {
            let key = runKey(length: mask.nonzeroBitCount, sum: digitsOf(mask).reduce(0, +))
            groups[key, default: []].append(mask)
        }
        return groups
    }()

    public static func masks(length: Int, sum: Int) -> [Int] {
        byRun[runKey(length: length, sum: sum)] ?? []
    }

    public static func digitsOf(_ mask: Int) -> [Int] {
        (1...Self.maxDigit).filter { mask & bit($0) != 0 }
    }

    public static func bit(_ digit: Int) -> Int {
        1 << (digit - 1)
    }

    private static func runKey(length: Int, sum: Int) -> Int {
        length * sumsPerLength + sum
    }

    public static func ordered(_ sets: [[CombinationDigit]], _ order: CombinationOrder) -> [[CombinationDigit]] {
        switch order {
        case .increasing:
            sets
        case .decreasing:
            sets.map { Array($0.reversed()) }.reversed()
        }
    }
}
