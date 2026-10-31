import PuzzlesCore
import Testing

@testable import FiveLettersEngine

private let words = Words(answers: ["crane", "slate", "trace"], guesses: ["adieu", "audio", "crate", "react", "stale"])

extension GameState {
    fileprivate func enter(_ word: String) -> GameState {
        word.reduce(self) { $0.type($1) }.submit(words: words)
    }
}

struct GameStateTests {
    @Test("given a typed word when it is submitted then it becomes a guess and typing clears")
    func submitBecomesGuess() {
        // Act
        let after = GameState(answer: "CRANE").enter("adieu")

        // Assert
        #expect(after.guesses == ["ADIEU"])
        #expect(after.typing.isEmpty)
    }

    @Test(
        "given an unacceptable word when it is submitted then it is rejected and kept",
        arguments: [("cra", Rejection.tooShort), ("zzzzz", Rejection.notAWord)]
    )
    func unacceptableRejected(word: String, rejection: Rejection) {
        // Act
        let after = GameState(answer: "CRANE").enter(word)

        // Assert
        #expect(after.guesses.isEmpty)
        #expect(after.typing == word.uppercased())
        #expect(after.rejection == rejection)
    }

    @Test("given hard mode and a green letter when a guess drops it then it is rejected")
    func hardModeRejects() {
        // Arrange
        let game = GameState(answer: "CRANE", hardMode: true).enter("crate")

        // Act
        let after = game.enter("adieu")

        // Assert
        #expect(after.rejection == .mustUseHints)
    }

    @Test("given hard mode when a guess keeps every hint then it is accepted")
    func hardModeAccepts() {
        // Arrange
        let game = GameState(answer: "CRANE", hardMode: true).enter("react")

        // Act
        let after = game.enter("trace")

        // Assert
        #expect(after.guesses.count == 2)
    }

    @Test("given the answer when it is guessed then the game is won and further typing does nothing")
    func winStopsTyping() {
        // Arrange
        let game = GameState(answer: "CRANE").enter("adieu").enter("crane")

        // Act
        let after = game.type("a")

        // Assert
        #expect(after.isWon)
        #expect(after.typing.isEmpty)
    }

    @Test("given six wrong guesses when the last is submitted then the game is lost")
    func sixWrongLoses() {
        // Act
        let after = (1...6).reduce(GameState(answer: "CRANE")) { state, _ in state.enter("adieu") }

        // Assert
        #expect(after.isLost)
    }

    @Test("given a won game when it is shared then the grid shows colours and no letters")
    func shareGrid() {
        // Arrange
        let game = GameState(answer: "CRANE").enter("trace").enter("crane")

        // Act
        let text = game.shareText(title: "Five Letters 1")

        // Assert
        #expect(text == "Five Letters 1 2/6\n\n⬜🟩🟩🟨🟩\n🟩🟩🟩🟩🟩")
    }

    @Test("given guesses when the keyboard is coloured then each letter shows its best mark")
    func keyboardMarks() {
        // Act
        let marks = GameState(answer: "CRANE").enter("react").enter("trace").letterMarks

        // Assert
        #expect(marks["R"] == .correct)
        #expect(marks["T"] == .absent)
    }

    @Test("given the same date when the daily word is picked twice then it matches, and the next day differs")
    func dailyStable() {
        // Arrange
        let big = Words(
            answers: (1...50).map { String("w\(String(repeating: "a", count: 4 - String($0).count))\($0)".prefix(5)) }, guesses: [])
        let day = CalendarDay(year: 2026, month: 11, day: 1)

        // Act
        let picks = [big.daily(day), big.daily(day), big.daily(day.adding(days: 1))]

        // Assert
        #expect(picks[0] == picks[1])
        #expect(picks[0] != picks[2])
        #expect(Words.dayNumber(day) == 8)
    }

    @Test("given answers when one is appended then every earlier daily word stays the same")
    func appendKeepsDailies() {
        // Arrange
        let answers = (0..<944).map { index in
            let codes = (0..<5).map { UInt8(97 + ((index >> ($0 * 2)) & 3) + $0 * 4) }
            return String(decoding: codes, as: UTF8.self)
        }
        let before = Words(answers: answers, guesses: [])
        let after = Words(answers: answers + ["zesty"], guesses: [])
        let days = (0..<944).map { Words.firstDay.adding(days: $0) }

        // Act
        let changed = days.filter { before.daily($0) != after.daily($0) }

        // Assert
        #expect(changed.isEmpty)
        #expect(after.daily(Words.firstDay.adding(days: 944)) == "ZESTY")
    }

    @Test("given an answer missing from the word list when it is guessed then it is accepted and wins")
    func unlistedAnswerWins() {
        // Act
        let after = GameState(answer: "GEEKY").enter("geeky")

        // Assert
        #expect(after.isWon)
    }

    @Test("given a guess when a hint is asked for then it gives the first letter not yet found in place")
    func hint() {
        // Arrange
        let game = GameState(answer: "CRANE", guesses: ["CLOUD"])

        // Act
        let hint = game.hintLetter()

        // Assert
        #expect(hint?.index == 1)
        #expect(hint?.letter == "R")
    }

    @Test("given a game when the word is revealed then the game is over and lost")
    func reveal() {
        // Act
        let game = GameState(answer: "CRANE", guesses: ["CLOUD"]).revealWord()

        // Assert
        #expect(game.isOver)
        #expect(game.isLost)
    }
}
