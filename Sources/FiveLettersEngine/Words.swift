import PuzzlesCore

public let wordLength = 5
public let maxGuesses = 6

public final class Words: Sendable {
    public static let firstDay = CalendarDay(year: 2026, month: 10, day: 25)
    private static let dailyOrderSeed: Int64 = 5
    private static let shuffledAnswerCount = 944

    public let answers: [String]
    private let allowed: Set<String>
    private let dailyOrder: [String]

    public init(answers: [String], guesses: [String]) {
        let cleanAnswers = answers.map(Words.clean).filter { $0.count == wordLength }
        self.answers = cleanAnswers
        allowed = Set(guesses.map(Words.clean) + cleanAnswers)
        var random = XorWowRandom(seed: Words.dailyOrderSeed)
        dailyOrder =
            Array(cleanAnswers.prefix(Words.shuffledAnswerCount)).shuffled(using: &random)
            + cleanAnswers.dropFirst(Words.shuffledAnswerCount)
    }

    public func isAllowed(_ word: String) -> Bool {
        allowed.contains(word)
    }

    public func daily(_ date: CalendarDay) -> String {
        let count = dailyOrder.count
        let index = ((Words.dayNumber(date) - 1) % count + count) % count
        return dailyOrder[index]
    }

    public func random(seed: Int64) -> String {
        var random = XorWowRandom(seed: seed)
        return answers[random.nextInt(below: answers.count)]
    }

    public static func dayNumber(_ date: CalendarDay) -> Int {
        date.days(since: firstDay) + 1
    }

    private static func clean(_ word: String) -> String {
        word.trimmingWhitespace().uppercased()
    }
}

extension String {
    fileprivate func trimmingWhitespace() -> String {
        var view = Substring(self)
        while view.first?.isWhitespace == true {
            view.removeFirst()
        }
        while view.last?.isWhitespace == true {
            view.removeLast()
        }
        return String(view)
    }
}
