import SlideOutEngine
import SwiftUI

struct SlideOutBoardView: View {
    let board: Board
    let hint: Move?
    let onSlide: (Int, Int) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = SlideColors.of(scheme)
        GeometryReader { proxy in
            let cell = proxy.size.width / CGFloat(boardSize)
            ZStack(alignment: .topLeading) {
                SlideOutExitGap(colors: colors, height: cell + Self.tipLength * 2)
                    .offset(x: proxy.size.width, y: cell * CGFloat(exitRow) - Self.tipLength)
                ForEach(0..<boardSize * boardSize, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors.slot)
                        .frame(width: cell - 6, height: cell - 6)
                        .offset(
                            x: cell * CGFloat(index % boardSize) + 3,
                            y: cell * CGFloat(index / boardSize) + 3
                        )
                }
                ForEach(Array(board.blocks.enumerated()), id: \.offset) { index, block in
                    SlideOutBlockView(
                        index: index,
                        block: block,
                        range: board.range(index),
                        isHinted: hint?.block == index,
                        cell: cell,
                        colors: colors,
                        onSlide: onSlide
                    )
                    .id(block)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(Self.padding - Self.frameWidth)
        .background(colors.board, in: RoundedRectangle(cornerRadius: 12 - Self.frameWidth))
        .padding(Self.frameWidth)
        .background(colors.block, in: RoundedRectangle(cornerRadius: 12))
    }

    static let padding: CGFloat = 6
    static let frameWidth: CGFloat = 3
    static let tipLength: CGFloat = 4
}

private struct SlideOutExitGap: View {
    let colors: SlideColors
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle().fill(Color(uiColor: .systemBackground))
            VStack {
                UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2)
                    .fill(colors.exit)
                    .frame(width: SlideOutBoardView.frameWidth, height: SlideOutBoardView.tipLength)
                Spacer()
                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                    .fill(colors.exit)
                    .frame(width: SlideOutBoardView.frameWidth, height: SlideOutBoardView.tipLength)
            }
        }
        .frame(width: SlideOutBoardView.padding, height: height)
        .overlay(alignment: .trailing) {
            SlideOutExitArrow()
                .stroke(colors.exit, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 16)
                .offset(x: 16)
        }
    }
}

private struct SlideOutExitArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.width * 0.625, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.75))
        }
    }
}

private struct SlideOutBlockView: View {
    let index: Int
    let block: Block
    let range: ClosedRange<Int>
    let isHinted: Bool
    let cell: CGFloat
    let colors: SlideColors
    let onSlide: (Int, Int) -> Void

    @State private var drag: CGFloat = 0

    private var clamped: CGFloat {
        let low = CGFloat(range.lowerBound - block.position) * cell
        let high = CGFloat(range.upperBound - block.position) * cell
        return min(max(drag, low), high)
    }

    var body: some View {
        let isTarget = index == 0
        let width = block.horizontal ? cell * CGFloat(block.length) : cell
        let height = block.horizontal ? cell : cell * CGFloat(block.length)
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8).fill(isTarget ? colors.targetEdge : colors.blockEdge)
            RoundedRectangle(cornerRadius: 8)
                .fill(isTarget ? colors.target : colors.block)
                .frame(height: (height - 6) * 0.88)
            if isHinted {
                RoundedRectangle(cornerRadius: 8).stroke(colors.hint, lineWidth: 3)
            }
        }
        .frame(width: width - 6, height: height - 6)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(isTarget ? "Red block" : "Block \(index)")
        .accessibilityIdentifier("block_\(index)")
        .offset(
            x: cell * CGFloat(block.col) + 3 + (block.horizontal ? clamped : 0),
            y: cell * CGFloat(block.row) + 3 + (block.horizontal ? 0 : clamped)
        )
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    drag = block.horizontal ? value.translation.width : value.translation.height
                }
                .onEnded { _ in
                    let steps = Int((clamped / cell).rounded())
                    drag = 0
                    onSlide(index, block.position + steps)
                }
        )
    }
}
