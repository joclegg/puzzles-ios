public let sizes = [6, 8, 10, 12]

public let maxDigit = 9

public struct Run: Sendable, Equatable {
    public let cells: [Int]
    public let sum: Int
    public let isAcross: Bool
    public let clueCell: Int

    public init(cells: [Int], sum: Int, isAcross: Bool, clueCell: Int) {
        self.cells = cells
        self.sum = sum
        self.isAcross = isAcross
        self.clueCell = clueCell
    }
}

public struct Puzzle: Sendable, Equatable {
    public let size: Int
    public let solution: [Int]
    public let givens: Set<Int>
    public let isWhite: [Bool]
    public let runs: [Run]
    public let runsOf: [Int: [Run]]
    public let acrossClues: [Int: Int]
    public let downClues: [Int: Int]

    public init(size: Int, solution: [Int], givens: Set<Int> = []) {
        self.size = size
        self.solution = solution
        self.givens = givens
        let isWhite = solution.map { $0 != 0 }
        self.isWhite = isWhite
        let runs = Puzzle.findRuns(size: size, solution: solution, isWhite: isWhite)
        self.runs = runs
        var runsOf: [Int: [Run]] = [:]
        var acrossClues: [Int: Int] = [:]
        var downClues: [Int: Int] = [:]
        for run in runs {
            for cell in run.cells {
                runsOf[cell, default: []].append(run)
            }
            if run.isAcross {
                acrossClues[run.clueCell] = run.sum
            } else {
                downClues[run.clueCell] = run.sum
            }
        }
        self.runsOf = runsOf
        self.acrossClues = acrossClues
        self.downClues = downClues
    }

    public func encode() -> String {
        let digits = solution.map(String.init).joined()
        let cells = givens.sorted().map(String.init).joined(separator: ",")
        return "\(size);\(digits);\(cells)"
    }

    public static func decode(_ text: String) -> Puzzle? {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 3, let size = Int(parts[0]), size > 0 else {
            return nil
        }
        var solution: [Int] = []
        for character in parts[1] {
            guard let ascii = character.asciiValue, (48...57).contains(ascii) else {
                return nil
            }
            solution.append(Int(ascii) - 48)
        }
        guard solution.count == size * size else {
            return nil
        }
        var givens: Set<Int> = []
        for part in parts[2].split(separator: ",") {
            guard let cell = Int(part) else {
                return nil
            }
            givens.insert(cell)
        }
        return Puzzle(size: size, solution: solution, givens: givens)
    }

    private static func findRuns(size: Int, solution: [Int], isWhite: [Bool]) -> [Run] {
        var runs: [Run] = []
        for across in [true, false] {
            for line in 0..<size {
                let cells = (0..<size).map { across ? line * size + $0 : $0 * size + line }
                for segment in segments(cells: cells, isWhite: isWhite) {
                    runs.append(
                        Run(
                            cells: segment,
                            sum: segment.reduce(0) { $0 + solution[$1] },
                            isAcross: across,
                            clueCell: across ? segment[0] - 1 : segment[0] - size
                        )
                    )
                }
            }
        }
        return runs
    }

    private static func segments(cells: [Int], isWhite: [Bool]) -> [[Int]] {
        var found: [[Int]] = []
        var current: [Int] = []
        for cell in cells + [-1] {
            if cell >= 0 && isWhite[cell] {
                current.append(cell)
            } else {
                if current.count > 1 {
                    found.append(current)
                }
                current = []
            }
        }
        return found
    }
}

public enum Combinations {
    private static let sumsPerLength = 100

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
        (1...maxDigit).filter { mask & bit($0) != 0 }
    }

    public static func bit(_ digit: Int) -> Int {
        1 << (digit - 1)
    }

    private static func runKey(length: Int, sum: Int) -> Int {
        length * sumsPerLength + sum
    }
}
