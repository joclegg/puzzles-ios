import SightlinesEngine
import SwiftUI

struct SightlinesBoardView: View {
    let state: GameState
    let markBroken: Bool
    let showSeen: Bool
    let onDot: (Int) -> Void

    private let gap: CGFloat = 5

    var body: some View {
        let size = state.grid.size
        let broken = markBroken ? state.brokenCells : []
        VStack(spacing: gap) {
            ForEach(0..<size, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<size, id: \.self) { col in
                        let cell = row * size + col
                        dot(cell, broken: broken.contains(cell))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dot(_ cell: Int, broken: Bool) -> some View {
        SightlinesDotView(
            dot: state.grid.dots[cell],
            number: state.puzzle.numbers[cell],
            seen: showSeen && state.puzzle.numbers[cell] != nil ? state.grid.seen(cell) : nil,
            given: state.puzzle.isGiven(cell),
            shaded: state.hintSight.contains(cell),
            hinted: state.hintTargets.contains(cell),
            broken: broken,
            tag: dotTag(cell: cell, size: state.grid.size),
            onTap: { onDot(cell) }
        )
    }
}

private struct SightlinesDotView: View {
    let dot: Dot
    let number: Int?
    let seen: Int?
    let given: Bool
    let shaded: Bool
    let hinted: Bool
    let broken: Bool
    let tag: String
    let onTap: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 8)

    private var colours: (face: Color, edge: Color) {
        switch dot {
        case .red:
            (SightlinesColors.red, SightlinesColors.redEdge)
        case .blue:
            (SightlinesColors.blue, SightlinesColors.blueEdge)
        case .empty:
            shaded ? (SightlinesColors.hintLine, SightlinesColors.hintLine) : (SightlinesColors.emptyTile, SightlinesColors.emptyTile)
        }
    }

    private var stateText: String {
        var parts = [dot == .blue ? "blue" : dot == .red ? "red" : "empty"]
        if given {
            parts.append("given")
        }
        if broken {
            parts.append("broken")
        }
        if hinted {
            parts.append("hint")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .top) {
                shape.fill(colours.edge)
                shape.fill(colours.face).frame(height: proxy.size.height * 0.9)
                    .overlay {
                        if let number {
                            Text("\(number)")
                                .font(.system(size: width * 0.42, weight: .medium))
                                .foregroundStyle(SightlinesColors.number)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let seen {
                            Text("\(seen)")
                                .font(.system(size: width * 0.42 * 0.42))
                                .foregroundStyle(SightlinesColors.number)
                                .padding(.trailing, 5)
                                .padding(.top, 2)
                                .accessibilityIdentifier("\(tag)_seen")
                        }
                    }
                if hinted {
                    shape.strokeBorder(SightlinesColors.hintTarget, lineWidth: 3)
                } else if broken {
                    shape.strokeBorder(SightlinesColors.broken, lineWidth: 3)
                }
            }
        }
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: seen != nil ? .contain : .ignore)
        .accessibilityLabel(number.map { "\($0), \(stateText)" } ?? stateText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(tag)
    }
}
