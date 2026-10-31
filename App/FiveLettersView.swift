import FiveLettersEngine
import PuzzlesCore
import SwiftUI

struct FiveLettersView: View {
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    @State private var words: Words?
    @State private var game: GameState?

    var body: some View {
        Group {
            if let game {
                content(game)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Five Letters")
        .navigationBarTitleDisplayMode(.inline)
        .task { await start() }
    }

    private func content(_ game: GameState) -> some View {
        VStack(spacing: 16) {
            board(game)
            Text(message(game))
                .font(.headline)
                .accessibilityIdentifier("message")
                .frame(minHeight: 24)
            Spacer()
            keyboard(game)
        }
        .padding()
    }

    private func board(_ game: GameState) -> some View {
        let marks = game.marks
        return VStack(spacing: 6) {
            ForEach(0..<maxGuesses, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<wordLength, id: \.self) { column in
                        tile(
                            letter: letter(game, row: row, column: column),
                            mark: row < marks.count ? marks[row][column] : nil
                        )
                        .accessibilityIdentifier("letter_r\(row + 1)c\(column + 1)")
                    }
                }
            }
        }
    }

    private func tile(letter: String, mark: Mark?) -> some View {
        Text(letter)
            .font(.title.bold())
            .foregroundStyle(mark == nil ? Color.primary : Color.white)
            .frame(width: 56, height: 56)
            .background(mark.map(color) ?? Color.clear)
            .overlay {
                if mark == nil {
                    Rectangle().stroke(Color.secondary)
                }
            }
    }

    private func keyboard(_ game: GameState) -> some View {
        let letterMarks = game.letterMarks
        return VStack(spacing: 6) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 4) {
                    if row.hasPrefix("Z") {
                        actionKey("Enter", id: "key_enter") { submit() }
                    }
                    ForEach(Array(row), id: \.self) { key in
                        Button {
                            update { $0.type(key) }
                        } label: {
                            Text(String(key))
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(letterMarks[key] == nil ? Color.primary : Color.white)
                                .background(letterMarks[key].map(color) ?? Color(.systemGray5))
                                .clipShape(.rect(cornerRadius: 4))
                        }
                        .accessibilityIdentifier("key_\(key)")
                    }
                    if row.hasPrefix("Z") {
                        actionKey("⌫", id: "key_delete") { update { $0.delete() } }
                    }
                }
            }
        }
    }

    private func actionKey(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.bold())
                .frame(width: 52, height: 48)
                .foregroundStyle(Color.primary)
                .background(Color(.systemGray4))
                .clipShape(.rect(cornerRadius: 4))
        }
        .accessibilityIdentifier(id)
    }

    private func letter(_ game: GameState, row: Int, column: Int) -> String {
        let source: String
        if row < game.guesses.count {
            source = game.guesses[row]
        } else if row == game.guesses.count {
            source = game.typing
        } else {
            source = ""
        }
        let letters = Array(source)
        return column < letters.count ? String(letters[column]) : ""
    }

    private func message(_ game: GameState) -> String {
        if game.isWon {
            return "You got it"
        }
        if game.isLost {
            return game.answer
        }
        switch game.rejection {
        case .tooShort:
            return "Not enough letters"
        case .notAWord:
            return "Not in the word list"
        case .mustUseHints:
            return "Use the hints you've found"
        case nil:
            return ""
        }
    }

    private func color(_ mark: Mark) -> Color {
        switch mark {
        case .correct:
            .green
        case .present:
            .orange
        case .absent:
            .gray
        }
    }

    private func update(_ change: (GameState) -> GameState) {
        if let game {
            self.game = change(game)
        }
    }

    private func submit() {
        if let words {
            update { $0.submit(words: words) }
        }
    }

    private func start() async {
        guard game == nil,
            let answers = try? await BankStore.shared.lines("words/answers.txt"),
            let guesses = try? await BankStore.shared.lines("words/guesses.txt")
        else {
            return
        }
        let loaded = Words(answers: answers, guesses: guesses)
        let today = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let day = CalendarDay(year: today.year ?? 2026, month: today.month ?? 1, day: today.day ?? 1)
        words = loaded
        game = GameState(answer: loaded.daily(day))
    }
}
