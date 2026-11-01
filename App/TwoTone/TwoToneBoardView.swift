import SwiftUI
import TwoToneEngine

struct TwoToneBoardView: View {
    private static let gap: CGFloat = 5

    let grid: TwoToneEngine.Grid
    let marks: BoardMarks
    let showGivens: Bool
    let onTile: (Int) -> Void

    var body: some View {
        VStack(spacing: Self.gap) {
            ForEach(0..<grid.size, id: \.self) { row in
                HStack(spacing: Self.gap) {
                    ForEach(0..<grid.size, id: \.self) { column in
                        tile(row * grid.size + column, row: row + 1, column: column + 1)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func tile(_ cell: Int, row: Int, column: Int) -> some View {
        let tile = grid.tiles[cell]
        let given = marks.givens.contains(cell)
        return ZStack {
            Button {
                onTile(cell)
            } label: {
                TwoToneTileFace(face: face(tile, cell), edge: edge(tile, cell), outline: outline(cell))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tile_r\(row)c\(column)")
            .accessibilityLabel("Row \(row), column \(column)")
            .accessibilityValue(describe(tile, cell: cell, given: given))
            if given && showGivens {
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Starting tile")
                    .accessibilityIdentifier("given_marker")
            }
        }
    }

    private func describe(_ tile: Tile, cell: Int, given: Bool) -> String {
        var parts = [tile == .red ? "Red" : tile == .blue ? "Blue" : "Empty"]
        if given {
            parts.append("starting tile")
        }
        if marks.broken.contains(cell) {
            parts.append("breaks a rule")
        }
        if marks.hintTargets.contains(cell) {
            parts.append("hinted")
        }
        return parts.joined(separator: ", ")
    }

    private func face(_ tile: Tile, _ cell: Int) -> Color {
        switch tile {
        case .red:
            TwoToneColors.red
        case .blue:
            TwoToneColors.blue
        case .empty:
            marks.hintLine.contains(cell) ? TwoToneColors.hintLine : TwoToneColors.emptyTile
        }
    }

    private func edge(_ tile: Tile, _ cell: Int) -> Color {
        switch tile {
        case .red:
            TwoToneColors.redEdge
        case .blue:
            TwoToneColors.blueEdge
        case .empty:
            face(tile, cell)
        }
    }

    private func outline(_ cell: Int) -> Color? {
        if marks.hintTargets.contains(cell) {
            return TwoToneColors.hintTarget
        }
        if marks.hintTwin.contains(cell) {
            return TwoToneColors.hintTarget.opacity(0.5)
        }
        if marks.broken.contains(cell) {
            return TwoToneColors.broken
        }
        return nil
    }
}

private struct TwoToneTileFace: View {
    private static let shape = RoundedRectangle(cornerRadius: 6)
    private static let faceFraction: CGFloat = 0.9

    let face: Color
    let edge: Color
    let outline: Color?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Self.shape.fill(edge)
                Self.shape.fill(face).frame(height: proxy.size.height * Self.faceFraction)
                if let outline {
                    Self.shape.strokeBorder(outline, lineWidth: 3)
                }
            }
        }
        .contentShape(Self.shape)
    }
}

struct TwoToneColourPicker: View {
    @Binding var colour: Tile

    var body: some View {
        HStack(spacing: 20) {
            option(.red, TwoToneColors.red, "Red", "colour_red")
            option(.blue, TwoToneColors.blue, "Blue", "colour_blue")
        }
    }

    private func option(_ tile: Tile, _ fill: Color, _ name: String, _ tag: String) -> some View {
        Button {
            colour = tile
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(fill)
                .frame(width: 56, height: 56)
                .overlay {
                    if colour == tile {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(.primary, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityIdentifier(tag)
        .accessibilityAddTraits(colour == tile ? .isSelected : [])
    }
}
