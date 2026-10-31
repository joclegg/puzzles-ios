import KakuroEngine
import SwiftUI

struct KakuroBoardView: View {
    let game: GameState
    let highlightRuns: Bool
    let onCell: (Int) -> Void

    @Environment(\.colorScheme) private var scheme

    private var colors: KakuroColors {
        KakuroColors.of(scheme)
    }

    var body: some View {
        let size = game.puzzle.size
        let wrong = game.shownWrongCells.union(game.rejected.map { [$0] } ?? [])
        let runCells = highlightRuns ? game.highlightedRunCells : []
        let sameDigit = game.sameDigitCells
        GeometryReader { proxy in
            let side = (proxy.size.width - 1) / CGFloat(size)
            VStack(spacing: 0) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<size, id: \.self) { col in
                            let cell = row * size + col
                            Group {
                                if game.puzzle.isWhite[cell] {
                                    whiteCell(cell, row: row, col: col, side: side, wrong: wrong, runCells: runCells, sameDigit: sameDigit)
                                } else {
                                    blockCell(cell, side: side)
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

    private func background(_ cell: Int, runCells: Set<Int>, sameDigit: Set<Int>) -> Color {
        if cell == game.selected {
            return colors.selected
        }
        if sameDigit.contains(cell) {
            return colors.sameDigit
        }
        if game.puzzle.givens.contains(cell) {
            return colors.givenCell
        }
        return runCells.contains(cell) ? colors.run : colors.background
    }

    private func whiteCell(
        _ cell: Int, row: Int, col: Int, side: CGFloat, wrong: Set<Int>, runCells: Set<Int>, sameDigit: Set<Int>
    ) -> some View {
        let value = game.values[cell]
        let isWrong = wrong.contains(cell)
        let marked = game.marked.contains(cell)
        let given = game.puzzle.givens.contains(cell)
        let flags = [isWrong ? "wrong" : nil, given ? "given" : nil, marked ? "marked" : nil].compactMap { $0 }
        return Button {
            onCell(cell)
        } label: {
            ZStack {
                background(cell, runCells: runCells, sameDigit: sameDigit)
                if value != 0 {
                    Text("\(value)")
                        .font(.system(size: side * 0.55))
                        .foregroundStyle(isWrong ? colors.wrong : colors.digit)
                } else if game.notes[cell] != 0 {
                    notes(game.notes[cell], side: side)
                }
                if marked {
                    RoundedRectangle(cornerRadius: 3).stroke(colors.trialMark, lineWidth: 2.5).padding(1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == 0 ? "" : "\(value)")
        .accessibilityValue(flags.joined(separator: " "))
        .accessibilityIdentifier("cell_r\(row + 1)c\(col + 1)")
        .accessibilityAddTraits(cell == game.selected ? .isSelected : [])
    }

    private func notes(_ mask: Int, side: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { noteRow in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { noteCol in
                        let digit = noteRow * 3 + noteCol + 1
                        Text(mask & Combinations.bit(digit) != 0 ? "\(digit)" : " ")
                            .font(.system(size: side * 0.2))
                            .foregroundStyle(colors.note)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(1)
    }

    private func blockCell(_ cell: Int, side: CGFloat) -> some View {
        let across = game.puzzle.acrossClues[cell]
        let down = game.puzzle.downClues[cell]
        return ZStack {
            colors.block
            if across != nil || down != nil {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: side, y: side))
                }
                .stroke(colors.line, lineWidth: 1)
            }
            if let across {
                clue(across, side: side).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 3)
                    .padding(.top, 1)
            }
            if let down {
                clue(down, side: side).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 3)
                    .padding(.bottom, 1)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func clue(_ value: Int, side: CGFloat) -> some View {
        Text("\(value)")
            .font(.system(size: side * 0.3, weight: .semibold))
            .foregroundStyle(colors.clue)
    }
}

struct KakuroPadTool {
    let symbol: String
    let description: String
    let tag: String
    let on: Bool
    let action: () -> Void
}

struct KakuroNumberPad: View {
    let activeDigit: Int?
    let doneDigits: Set<Int>
    let tools: [KakuroPadTool]
    let onDigit: (Int) -> Void

    @Environment(\.colorScheme) private var scheme

    private static let perRow = 6
    private static let gap: CGFloat = 6

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Self.gap), count: Self.perRow)
        LazyVGrid(columns: columns, spacing: Self.gap) {
            ForEach(1...maxDigit, id: \.self, content: digitKey)
            ForEach(tools, id: \.tag) { KakuroPadToolKey(tool: $0) }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        let colors = KakuroColors.of(scheme)
        let done = doneDigits.contains(digit)
        let active = digit == activeDigit && !done
        return Button {
            onDigit(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 34))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(done ? Color.secondary.opacity(0.4) : colors.accent)
                .background(active ? colors.selected : .clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(done ? 0.1 : 0.3), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done)
        .accessibilityIdentifier("digit_\(digit)")
        .accessibilityAddTraits(digit == activeDigit ? .isSelected : [])
    }
}

private struct KakuroPadToolKey: View {
    let tool: KakuroPadTool

    @Environment(\.colorScheme) private var scheme
    @State private var showTip = false
    @State private var heldForTip = false

    var body: some View {
        let colors = KakuroColors.of(scheme)
        Button {
            if heldForTip {
                heldForTip = false
            } else {
                tool.action()
            }
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(tool.on ? colors.selected : colors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                heldForTip = true
                showTip = true
            }
        )
        .popover(isPresented: $showTip) {
            Text(tool.description).font(.footnote).padding(10).presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(tool.description)
        .accessibilityIdentifier(tool.tag)
        .accessibilityAddTraits(tool.on ? .isSelected : [])
    }
}
