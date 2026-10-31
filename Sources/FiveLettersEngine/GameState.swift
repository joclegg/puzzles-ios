public enum Mark: Int, Sendable, CaseIterable {
    case correct
    case present
    case absent

    public var emoji: String {
        switch self {
        case .correct:
            "🟩"
        case .present:
            "🟨"
        case .absent:
            "⬜"
        }
    }
}

public enum Rejection: Sendable, Equatable {
    case tooShort
    case notAWord
    case mustUseHints
}

public func score(guess: String, answer: String) -> [Mark] {
    let guessLetters = Array(guess)
    let answerLetters = Array(answer)
    var marks = [Mark](repeating: .absent, count: wordLength)
    var unmatched: [Character: Int] = [:]
    for index in 0..<wordLength {
        if guessLetters[index] == answerLetters[index] {
            marks[index] = .correct
        } else {
            unmatched[answerLetters[index], default: 0] += 1
        }
    }
    for index in 0..<wordLength {
        let left = unmatched[guessLetters[index], default: 0]
        if marks[index] != .correct && left > 0 {
            marks[index] = .present
            unmatched[guessLetters[index]] = left - 1
        }
    }
    return marks
}

public struct GameState: Sendable, Equatable {
    public var answer: String
    public var guesses: [String]
    public var typing: String
    public var hardMode: Bool
    public var rejection: Rejection?
    public var revealed: Bool

    public init(
        answer: String,
        guesses: [String] = [],
        typing: String = "",
        hardMode: Bool = false,
        rejection: Rejection? = nil,
        revealed: Bool = false
    ) {
        self.answer = answer
        self.guesses = guesses
        self.typing = typing
        self.hardMode = hardMode
        self.rejection = rejection
        self.revealed = revealed
    }

    public var marks: [[Mark]] {
        guesses.map { score(guess: $0, answer: answer) }
    }

    public var isWon: Bool {
        guesses.contains(answer)
    }

    public var isLost: Bool {
        !isWon && (revealed || guesses.count == maxGuesses)
    }

    public var isOver: Bool {
        isWon || isLost
    }

    public var letterMarks: [Character: Mark] {
        var result: [Character: Mark] = [:]
        for (guess, row) in zip(guesses, marks) {
            for (letter, mark) in zip(guess, row) {
                if let current = result[letter], current.rawValue <= mark.rawValue {
                    continue
                }
                result[letter] = mark
            }
        }
        return result
    }

    public func hintLetter() -> (index: Int, letter: Character)? {
        let letters = Array(answer)
        guard
            let index = letters.indices.first(where: { position in
                !guesses.contains { Array($0)[position] == letters[position] }
            })
        else {
            return nil
        }
        return (index, letters[index])
    }

    public func revealWord() -> GameState {
        var next = self
        next.typing = ""
        next.rejection = nil
        next.revealed = true
        return next
    }

    public func type(_ letter: Character) -> GameState {
        if isOver || typing.count == wordLength || !letter.isLetter {
            return self
        }
        var next = self
        next.typing += letter.uppercased()
        next.rejection = nil
        return next
    }

    public func delete() -> GameState {
        if isOver || typing.isEmpty {
            return self
        }
        var next = self
        next.typing.removeLast()
        next.rejection = nil
        return next
    }

    public func submit(words: Words) -> GameState {
        if isOver {
            return self
        }
        var next = self
        if typing.count < wordLength {
            next.rejection = .tooShort
        } else if typing != answer && !words.isAllowed(typing) {
            next.rejection = .notAWord
        } else if hardMode && !usesHints(typing) {
            next.rejection = .mustUseHints
        } else {
            next.guesses.append(typing)
            next.typing = ""
            next.rejection = nil
        }
        return next
    }

    public func shareText(title: String) -> String {
        let result = isWon ? String(guesses.count) : "X"
        let grid = marks.map { row in row.map(\.emoji).joined() }.joined(separator: "\n")
        return "\(title) \(result)/\(maxGuesses)\(hardMode ? "*" : "")\n\n\(grid)"
    }

    private func usesHints(_ word: String) -> Bool {
        let wordLetters = Array(word)
        return zip(guesses, marks).allSatisfy { guess, row in
            let guessLetters = Array(guess)
            return row.indices.allSatisfy { index in
                switch row[index] {
                case .correct:
                    return wordLetters[index] == guessLetters[index]
                case .present:
                    let needed = guessLetters.indices.count {
                        guessLetters[$0] == guessLetters[index] && row[$0] != .absent
                    }
                    return wordLetters.count { $0 == guessLetters[index] } >= needed
                case .absent:
                    return true
                }
            }
        }
    }
}
