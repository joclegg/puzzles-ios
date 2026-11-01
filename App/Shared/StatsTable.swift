import PuzzlesCore
import SwiftUI

struct StatsRow: Identifiable {
    let id: String
    let cells: [String]
    let identifiers: [String?]

    static func size(_ size: Int, label: String, solved: Int, played: Int, bestMs: Int64?, averageMs: Int64?) -> StatsRow {
        let tag = "size_\(size)"
        return StatsRow(
            id: tag,
            cells: [
                label, "\(solved)/\(played)", bestMs.map { formatDuration($0) } ?? "–",
                averageMs.map { formatDuration($0) } ?? "–",
            ],
            identifiers: [nil, "\(tag)_solved", "\(tag)_best", nil]
        )
    }
}

struct StatsTable: View {
    let header: [String]
    let rows: [StatsRow]

    var body: some View {
        VStack(spacing: 8) {
            line(header, identifiers: [], header: true)
            ForEach(rows) { row in
                line(row.cells, identifiers: row.identifiers, header: false)
            }
        }
    }

    private func line(_ cells: [String], identifiers: [String?], header: Bool) -> some View {
        HStack {
            ForEach(cells.indices, id: \.self) { index in
                cell(cells[index], header: header, identifier: index < identifiers.count ? identifiers[index] : nil)
            }
        }
    }

    @ViewBuilder
    private func cell(_ text: String, header: Bool, identifier: String?) -> some View {
        let label = Text(text)
            .fontWeight(header ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        if let identifier {
            label.accessibilityIdentifier(identifier)
        } else {
            label
        }
    }
}
