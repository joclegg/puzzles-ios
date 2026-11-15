import CrosswordEngine
import SwiftUI

struct CrosswordBoardView: View {
    let game: GameState
    let onCell: (Int) -> Void

    @Environment(\.colorScheme) private var scheme

    private var colors: CrosswordColors {
        CrosswordColors.of(scheme)
    }

    var body: some View {
        let size = game.puzzle.size
        let wrong = game.shownWrongCells
        let word = game.highlightedCells
        GeometryReader { proxy in
            let side = (proxy.size.width - 1) / CGFloat(size)
            VStack(spacing: 0) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<size, id: \.self) { col in
                            let cell = row * size + col
                            Group {
                                if game.puzzle.isWhite[cell] {
                                    whiteCell(cell, row: row, col: col, side: side, wrong: wrong, word: word)
                                } else {
                                    colors.blockMark
                                }
                            }
                            .padding(0.5)
                            .frame(width: side, height: side)
                        }
                    }
                }
            }
            .padding(0.5)
            .background(colors.line)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func whiteCell(_ cell: Int, row: Int, col: Int, side: CGFloat, wrong: Set<Int>, word: Set<Int>) -> some View {
        let entry = game.entries[cell]
        let letter = entry == emptyMark ? "" : String(entry)
        let isWrong = wrong.contains(cell)
        let isSelected = cell == game.selected
        let background = isSelected ? colors.selected : word.contains(cell) ? colors.word : colors.background
        return Button {
            onCell(cell)
        } label: {
            ZStack(alignment: .topLeading) {
                background
                if let number = game.puzzle.numbers[cell] {
                    Text("\(number)")
                        .font(.system(size: side * 0.28))
                        .foregroundStyle(colors.number)
                        .padding(.leading, side * 0.06)
                }
                Text(letter)
                    .font(.system(size: side * 0.6, weight: .medium))
                    .foregroundStyle(isWrong ? colors.wrong : colors.letter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: side * 0.05)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(letter)
        .accessibilityValue(isWrong ? "wrong" : "")
        .accessibilityIdentifier("cell_r\(row + 1)c\(col + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
