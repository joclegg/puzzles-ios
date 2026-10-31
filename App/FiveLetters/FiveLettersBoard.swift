import FiveLettersEngine
import SwiftUI

struct FiveLettersBoard: View {
    let game: GameState
    private let theme = FiveLettersTheme()
    private let gap: CGFloat = 6

    private var rows: [String] {
        Array((game.guesses + (game.isOver ? [] : [game.typing])).prefix(maxGuesses))
    }

    var body: some View {
        GeometryReader { proxy in
            let tile = tileSize(in: proxy.size)
            let marks = game.marks
            let rows = rows
            VStack(spacing: gap) {
                ForEach(0..<maxGuesses, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<wordLength, id: \.self) { column in
                            tileView(
                                letter: letter(rows, row: row, column: column),
                                mark: row < marks.count ? marks[row][column] : nil,
                                size: tile
                            )
                            .accessibilityIdentifier("letter_r\(row + 1)c\(column + 1)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tileSize(in size: CGSize) -> CGFloat {
        let wide = (size.width - gap * CGFloat(wordLength - 1)) / CGFloat(wordLength)
        let tall = (size.height - gap * CGFloat(maxGuesses - 1)) / CGFloat(maxGuesses)
        return max(min(wide, tall), 1)
    }

    private func letter(_ rows: [String], row: Int, column: Int) -> String {
        guard row < rows.count else {
            return ""
        }
        let letters = Array(rows[row])
        return column < letters.count ? String(letters[column]) : ""
    }

    private func tileView(letter: String, mark: Mark?, size: CGFloat) -> some View {
        Text(letter)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(mark == nil ? theme.text : theme.markedText)
            .frame(width: size, height: size)
            .background(mark.map(theme.colour) ?? .clear, in: .rect(cornerRadius: 4))
            .overlay {
                if mark == nil {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(letter.isEmpty ? theme.emptyBorder : theme.typedBorder, lineWidth: 2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(letter)
            .accessibilityValue(mark.map { "\($0)" } ?? "")
    }
}

struct FiveLettersKeyboard: View {
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
    private static let keyHeight: CGFloat = 56
    private static let spacing: CGFloat = 5

    let letterMarks: [Character: Mark]
    let onLetter: (Character) -> Void
    let onEnter: () -> Void
    let onDelete: () -> Void
    private let theme = FiveLettersTheme()

    var body: some View {
        GeometryReader { proxy in
            let unit = (proxy.size.width - Self.spacing * 9) / 10
            let wide = unit * 1.5 + Self.spacing / 2
            VStack(spacing: 8) {
                ForEach(Self.rows, id: \.self) { row in
                    HStack(spacing: Self.spacing) {
                        if row.hasPrefix("Z") {
                            deleteKey(width: wide)
                        }
                        ForEach(Array(row), id: \.self) { letter in
                            let mark = letterMarks[letter]
                            key(
                                String(letter),
                                width: unit,
                                background: mark.map(theme.colour) ?? theme.key,
                                foreground: mark == nil ? theme.keyText : theme.markedText,
                                font: .system(size: 18, weight: .semibold)
                            ) {
                                onLetter(letter)
                            }
                            .accessibilityIdentifier("key_\(letter)")
                        }
                        if row.hasPrefix("Z") {
                            key(
                                "ENTER",
                                width: wide,
                                background: theme.key,
                                foreground: theme.keyText,
                                font: .system(size: 12, weight: .semibold),
                                action: onEnter
                            )
                            .accessibilityIdentifier("key_enter")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: Self.keyHeight * 3 + 16)
    }

    private func key(
        _ label: String,
        width: CGFloat,
        background: Color,
        foreground: Color,
        font: Font,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(foreground)
                .frame(width: width, height: Self.keyHeight)
                .background(background, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func deleteKey(width: CGFloat) -> some View {
        Button(action: onDelete) {
            PuzzleIcon.image("delete.left")
                .foregroundStyle(theme.keyText)
                .frame(width: width, height: Self.keyHeight)
                .background(theme.key, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
        .accessibilityIdentifier("key_delete")
    }
}
