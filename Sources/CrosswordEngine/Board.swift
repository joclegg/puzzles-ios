public let sizes = [11, 13, 15]

public let blockMark: Character = "#"

public let emptyMark: Character = "."

public func sizeName(_ size: Int) -> String {
    switch size {
    case 11:
        "Small"
    case 13:
        "Medium"
    case 15:
        "Large"
    default:
        "\(size) x \(size)"
    }
}

public struct Word: Sendable, Equatable, Hashable {
    public let number: Int
    public let isAcross: Bool
    public let cells: [Int]

    public init(number: Int, isAcross: Bool, cells: [Int]) {
        self.number = number
        self.isAcross = isAcross
        self.cells = cells
    }

    public var label: String {
        "\(number) \(isAcross ? "Across" : "Down")"
    }
}

public struct Puzzle: Sendable, Equatable {
    public let size: Int
    public let solution: [Character]
    public let isWhite: [Bool]
    public let numbers: [Int: Int]
    public let words: [Word]
    public let acrossWord: [Int: Int]
    public let downWord: [Int: Int]

    public init(size: Int, solution: [Character]) {
        self.size = size
        self.solution = solution
        let isWhite = solution.map { $0 != blockMark }
        self.isWhite = isWhite
        var numbers: [Int: Int] = [:]
        var across: [Word] = []
        var down: [Word] = []
        var next = 1
        for cell in solution.indices where isWhite[cell] {
            let row = cell / size
            let column = cell % size
            let startsAcross =
                (column == 0 || !isWhite[cell - 1]) && column + 1 < size && isWhite[cell + 1]
            let startsDown =
                (row == 0 || !isWhite[cell - size]) && row + 1 < size && isWhite[cell + size]
            guard startsAcross || startsDown else {
                continue
            }
            numbers[cell] = next
            if startsAcross {
                var cells: [Int] = []
                var current = cell
                while current / size == row && isWhite[current] {
                    cells.append(current)
                    current += 1
                    if current % size == 0 {
                        break
                    }
                }
                across.append(Word(number: next, isAcross: true, cells: cells))
            }
            if startsDown {
                var cells: [Int] = []
                var current = cell
                while current < solution.count && isWhite[current] {
                    cells.append(current)
                    current += size
                }
                down.append(Word(number: next, isAcross: false, cells: cells))
            }
            next += 1
        }
        self.numbers = numbers
        let words = across + down
        self.words = words
        var acrossWord: [Int: Int] = [:]
        var downWord: [Int: Int] = [:]
        for (index, word) in words.enumerated() {
            for cell in word.cells {
                if word.isAcross {
                    acrossWord[cell] = index
                } else {
                    downWord[cell] = index
                }
            }
        }
        self.acrossWord = acrossWord
        self.downWord = downWord
    }

    public func answer(_ word: Word) -> String {
        String(word.cells.map { solution[$0] })
    }

    public func encode() -> String {
        "\(size);\(String(solution))"
    }

    public static func decode(_ text: String) -> Puzzle? {
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count >= 2, let size = Int(parts[0]), size > 0 else {
            return nil
        }
        let solution = Array(parts[1])
        guard solution.count == size * size, solution.allSatisfy({ $0 == blockMark || isLetter($0) }) else {
            return nil
        }
        return Puzzle(size: size, solution: solution)
    }
}

public func isLetter(_ character: Character) -> Bool {
    guard let ascii = character.asciiValue else {
        return false
    }
    return (65...90).contains(ascii)
}

public enum ClueBook {
    public static func parse(_ lines: [String]) -> [String: String] {
        var clues: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ";") else {
                continue
            }
            let word = String(line[..<separator])
            let clue = String(line[line.index(after: separator)...])
            if !word.isEmpty && !clue.isEmpty {
                clues[word] = clue
            }
        }
        return clues
    }

    public static func text(for word: Word, in puzzle: Puzzle, clues: [String: String]) -> String {
        let clue = clues[puzzle.answer(word)] ?? ""
        return "\(clue) (\(word.cells.count))"
    }
}
