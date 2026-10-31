public let minWord = 3

public enum Level: Int, CaseIterable, Sendable {
    case five
    case six
    case seven

    public var letters: Int {
        switch self {
        case .five:
            5
        case .six:
            6
        case .seven:
            7
        }
    }

    public var words: ClosedRange<Int> {
        switch self {
        case .five:
            4...6
        case .six:
            5...8
        case .seven:
            6...10
        }
    }

    public var name: String {
        switch self {
        case .five:
            "FIVE"
        case .six:
            "SIX"
        case .seven:
            "SEVEN"
        }
    }

    public static func named(_ name: String) -> Level? {
        allCases.first { $0.name == name }
    }
}

public struct WordList: Sendable {
    public let valid: Set<String>
    public let common: Set<String>

    public init(valid: [String], common: [String]) {
        let validWords = Set(valid.map { $0.uppercased() })
        self.valid = validWords
        self.common = Set(
            common.map { $0.uppercased() }.filter { word in
                validWords.contains(word) && !WordList.isAmericanOnly(word, valid: validWords)
            }
        )
    }

    public static func fits(_ word: String, letters: String) -> Bool {
        var left: [Character: Int] = [:]
        for letter in letters {
            left[letter, default: 0] += 1
        }
        return word.allSatisfy { letter in
            let count = left[letter, default: 0]
            left[letter] = count - 1
            return count > 0
        }
    }

    private static func isAmericanOnly(_ word: String, valid: Set<String>) -> Bool {
        let suffixes = [("OR", "OUR"), ("ER", "RE"), ("IZE", "ISE"), ("IZED", "ISED"), ("ENSE", "ENCE")]
        let british = suffixes.contains { american, british in
            word.hasSuffix(american) && valid.contains(word.dropLast(american.count) + british)
        }
        return british || (word.hasPrefix("GRAY") && valid.contains("GREY" + word.dropFirst(4)))
    }
}
