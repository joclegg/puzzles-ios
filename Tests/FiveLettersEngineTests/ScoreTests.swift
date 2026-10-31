import Testing

@testable import FiveLettersEngine

struct ScoreTests {
    @Test(
        "given a guess and an answer when it is scored then repeated letters are only marked as often as the answer has them",
        arguments: [
            ("CRANE", "CRANE", "CCCCC"),
            ("TRACE", "CRANE", "ACCPC"),
            ("SPEED", "ABIDE", "AAPAP"),
            ("EERIE", "THEME", "PAAAC"),
            ("LLAMA", "HELLO", "PPAAA"),
            ("ROBOT", "FLOOR", "PPACA"),
        ]
    )
    func scoring(guess: String, answer: String, expected: String) {
        // Act
        let marks = score(guess: guess, answer: answer)

        // Assert
        let letters = marks.map { mark -> String in
            switch mark {
            case .correct:
                "C"
            case .present:
                "P"
            case .absent:
                "A"
            }
        }
        #expect(letters.joined() == expected)
    }
}
