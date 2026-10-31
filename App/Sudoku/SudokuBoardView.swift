import SudokuEngine
import SwiftUI

typealias SudokuGrid = SudokuEngine.Grid

struct SudokuCellData {
    var value: Int
    var notes: Int
    var given: Bool
    var wrong: Bool
    var highlight: Highlight
    var numberHighlighted: Bool
    var marked: Bool
}

struct SudokuBoardData {
    var cells: [SudokuCellData]
    var cages: [Cage]
    var wrongCages: Set<Int>
    var highlightDigit: Int?
    var boldPlacedDigits = true
    var greyGivenCells = true

    var grid: SudokuGrid {
        SudokuGrid.forCellCount(cells.count)
    }

    init(_ state: GameState) {
        cells = state.values.indices.map { cell in
            SudokuCellData(
                value: state.values[cell],
                notes: state.notes[cell],
                given: state.isGiven(cell),
                wrong: state.isWrong(cell) || state.rejected?.clashes.contains(cell) == true,
                highlight: state.highlight(cell),
                numberHighlighted: state.isNumberHighlighted(cell),
                marked: state.marked.contains(cell)
            )
        }
        cages = state.puzzle.cages
        wrongCages = Set(state.puzzle.cages.indices.filter { state.isCageWrong(state.puzzle.cages[$0]) })
        highlightDigit = state.noteHighlightDigit
    }
}

func sudokuCellTag(_ cell: Int, _ grid: SudokuGrid) -> String {
    "cell_r\(grid.rowOf(cell) + 1)c\(grid.colOf(cell) + 1)"
}

struct SudokuBoardView: View {
    let board: SudokuBoardData
    let onCell: (Int) -> Void
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let grid = board.grid
            let step = side / CGFloat(grid.size)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<grid.size, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<grid.size, id: \.self) { col in
                                cell(grid.cellAt(row: row, col: col), grid: grid, step: step)
                            }
                        }
                    }
                }
                lines(grid: grid, side: side)
                cageSums(grid: grid, step: step)
            }
            .frame(width: side, height: side)
            .background(palette.background)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func background(_ cell: SudokuCellData) -> Color {
        let grey = cell.given && board.greyGivenCells
        switch cell.highlight {
        case .selected:
            return palette.selected
        case .sameDigit, .noteMatch:
            return palette.sameDigit
        case .peer:
            return grey ? palette.givenPeer : palette.peer
        case .none:
            return grey ? palette.givenCell : .clear
        }
    }

    private func cell(_ index: Int, grid: SudokuGrid, step: CGFloat) -> some View {
        let data = board.cells[index]
        let inCage = board.cages.contains { $0.cells.contains(index) }
        return Button {
            onCell(index)
        } label: {
            ZStack {
                background(data)
                if data.value != 0 {
                    Text("\(data.value)")
                        .font(
                            .system(
                                size: step * (grid == .standard ? 0.72 : 0.64),
                                weight: !data.given && board.boldPlacedDigits ? .medium : .regular)
                        )
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(digitColor(data))
                } else if data.notes != 0 {
                    notes(data.notes, grid: grid, step: step, inCage: inCage)
                }
                if data.marked {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(palette.trialMark, lineWidth: 2.5)
                        .padding(1)
                }
            }
            .frame(width: step, height: step)
            .contentShape(Rectangle())
        }
        .buttonStyle(SudokuCellPress())
        .accessibilityLabel(data.value != 0 ? "\(data.value)" : "")
        .accessibilityIdentifier(sudokuCellTag(index, grid))
    }

    private func digitColor(_ data: SudokuCellData) -> Color {
        if data.wrong {
            return palette.wrong
        }
        return data.numberHighlighted ? palette.highlightedNote : palette.enteredDigit
    }

    private func notes(_ mask: Int, grid: SudokuGrid, step: CGFloat, inCage: Bool) -> some View {
        let inset = step * (inCage ? 0.13 : 0.06)
        let top = step * (inCage ? 0.27 : 0.06)
        let size = step * (inCage ? 0.21 : 0.26)
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = row * 3 + col
                        let on = grid.digits.contains(digit) && mask & digitBit(digit) != 0
                        let match = digit == board.highlightDigit
                        Text(on ? "\(digit)" : " ")
                            .font(.system(size: size, weight: match ? .bold : .regular))
                            .foregroundStyle(match ? palette.highlightedNote : palette.noteDigit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(EdgeInsets(top: top, leading: inset, bottom: inset, trailing: inset))
    }

    private func lines(grid: SudokuGrid, side: CGFloat) -> some View {
        Canvas { context, _ in
            let step = side / CGFloat(grid.size)
            for index in 0...grid.size {
                let at = CGFloat(index) * step
                var vertical = Path()
                vertical.move(to: CGPoint(x: at, y: 0))
                vertical.addLine(to: CGPoint(x: at, y: side))
                let thickVertical = index % grid.boxCols == 0
                context.stroke(
                    vertical, with: .color(thickVertical ? palette.thickLine : palette.thinLine),
                    lineWidth: thickVertical ? 2 : 1)
                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: at))
                horizontal.addLine(to: CGPoint(x: side, y: at))
                let thickHorizontal = index % grid.boxRows == 0
                context.stroke(
                    horizontal, with: .color(thickHorizontal ? palette.thickLine : palette.thinLine),
                    lineWidth: thickHorizontal ? 2 : 1)
            }
            for (index, cage) in board.cages.enumerated() {
                let path = cagePath(cage, grid: grid, step: step)
                context.stroke(
                    path, with: .color(board.wrongCages.contains(index) ? palette.wrong : palette.cageLine),
                    style: StrokeStyle(lineWidth: 1, dash: [step * 0.06, step * 0.05]))
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cagePath(_ cage: Cage, grid: SudokuGrid, step: CGFloat) -> Path {
        var path = Path()
        let members = Set(cage.cells)
        let inset = step * 0.06
        func same(_ row: Int, _ col: Int) -> Bool {
            (0..<grid.size).contains(row) && (0..<grid.size).contains(col)
                && members.contains(grid.cellAt(row: row, col: col))
        }
        func line(_ from: CGPoint, _ to: CGPoint) {
            path.move(to: from)
            path.addLine(to: to)
        }
        for cell in cage.cells {
            let row = grid.rowOf(cell)
            let col = grid.colOf(cell)
            let left = CGFloat(col) * step
            let top = CGFloat(row) * step
            let x0 = same(row, col - 1) ? left : left + inset
            let x1 = same(row, col + 1) ? left + step : left + step - inset
            let y0 = same(row - 1, col) ? top : top + inset
            let y1 = same(row + 1, col) ? top + step : top + step - inset
            if !same(row - 1, col) {
                line(CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y0))
            }
            if !same(row + 1, col) {
                line(CGPoint(x: x0, y: y1), CGPoint(x: x1, y: y1))
            }
            if !same(row, col - 1) {
                line(CGPoint(x: x0, y: y0), CGPoint(x: x0, y: y1))
            }
            if !same(row, col + 1) {
                line(CGPoint(x: x1, y: y0), CGPoint(x: x1, y: y1))
            }
        }
        return path
    }

    private func cageSums(grid: SudokuGrid, step: CGFloat) -> some View {
        ForEach(Array(board.cages.enumerated()), id: \.offset) { index, cage in
            let anchor = cage.cells.min() ?? 0
            let cellColor = background(board.cells[anchor])
            Text("\(cage.sum)")
                .font(.system(size: step * 0.24, weight: .medium))
                .foregroundStyle(board.wrongCages.contains(index) ? palette.wrong : palette.cageSum)
                .padding(.horizontal, 1.5)
                .background(cellColor == .clear ? palette.background : cellColor)
                .offset(
                    x: step * CGFloat(grid.colOf(anchor)) + step * 0.02,
                    y: step * CGFloat(grid.rowOf(anchor)) + step * 0.02
                )
                .allowsHitTesting(false)
                .accessibilityIdentifier("cage_sum_\(sudokuCellTag(anchor, grid).dropFirst(5))")
        }
    }
}

private struct SudokuCellPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct SudokuPadTool: Identifiable {
    let symbol: String
    let description: String
    let tag: String
    var on = false
    let action: () -> Void

    var id: String {
        tag
    }
}

struct SudokuPadView: View {
    var digits: ClosedRange<Int> = SudokuGrid.standard.digits
    var activeDigit: Int?
    var doneDigits: Set<Int> = []
    var counts: [Int] = []
    let tools: [SudokuPadTool]
    let onDigit: (Int) -> Void
    @State private var tooltip: String?
    @Environment(\.sudokuPalette) private var palette

    private static let keysPerRow = 6
    private static let gap: CGFloat = 6

    var body: some View {
        let keys: [PadKey] = digits.map(PadKey.digit) + tools.map(PadKey.tool)
        let rows = stride(from: 0, to: keys.count, by: Self.keysPerRow).map {
            Array(keys[$0..<min($0 + Self.keysPerRow, keys.count)])
        }
        VStack(spacing: Self.gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Self.gap) {
                    ForEach(row) { key in
                        switch key {
                        case .digit(let digit):
                            digitKey(digit)
                        case .tool(let tool):
                            toolKey(tool)
                        }
                    }
                    ForEach(0..<(Self.keysPerRow - row.count), id: \.self) { _ in
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let tooltip {
                Text(tooltip)
                    .font(.footnote)
                    .padding(8)
                    .background(palette.peer, in: RoundedRectangle(cornerRadius: 8))
                    .offset(y: -40)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        self.tooltip = nil
                    }
            }
        }
    }

    private enum PadKey: Identifiable {
        case digit(Int)
        case tool(SudokuPadTool)

        var id: String {
            switch self {
            case .digit(let digit):
                "digit_\(digit)"
            case .tool(let tool):
                tool.tag
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        let active = digit == activeDigit
        let done = doneDigits.contains(digit)
        let count = digit < counts.count ? counts[digit] : nil
        return Button {
            onDigit(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: digits.upperBound == SudokuGrid.standard.size ? 34 : 30))
                .minimumScaleFactor(0.6)
                .foregroundStyle(done ? palette.doneDigit : active ? palette.enteredDigit : palette.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(active && !done ? palette.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(done ? palette.doneDigit : palette.thinLine)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("digit_\(digit)")
        .overlay(alignment: .topTrailing) {
            if let count, !done {
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.noteDigit)
                    .padding(.top, 3)
                    .padding(.trailing, 5)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("digit_\(digit)_count")
            }
        }
    }

    private func toolKey(_ tool: SudokuPadTool) -> some View {
        Button(action: tool.action) {
            Image(systemName: tool.symbol)
                .font(.title3)
                .foregroundStyle(palette.enteredDigit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tool.on ? palette.selected : palette.peer, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
        .simultaneousGesture(LongPressGesture().onEnded { _ in tooltip = tool.description })
        .accessibilityLabel(tool.description)
        .accessibilityAddTraits(tool.on ? .isSelected : [])
        .accessibilityIdentifier(tool.tag)
    }
}
