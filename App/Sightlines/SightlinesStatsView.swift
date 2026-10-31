import SightlinesEngine
import SwiftUI

struct SightlinesStatsView: View {
    private let store = SightlinesStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 8) {
                    row("Size", "Solved", "Best", "Average", header: true, tag: nil)
                    ForEach(sizes, id: \.self) { size in
                        let stats = store.games.stats(size: size)
                        row(
                            sizeLabel(size),
                            "\(stats.solved)/\(stats.played)",
                            stats.bestMs.map { formatDuration(ms: $0) } ?? "–",
                            stats.averageMs.map { formatDuration(ms: $0) } ?? "–",
                            header: false,
                            tag: "size_\(size)"
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
                Text("Solved out of played. Abandoned puzzles count as played. Daily puzzles count under their size.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ size: String, _ solved: String, _ best: String, _ average: String, header: Bool, tag: String?) -> some View {
        HStack {
            cell(size, header, nil)
            cell(solved, header, tag.map { "\($0)_solved" })
            cell(best, header, tag.map { "\($0)_best" })
            cell(average, header, nil)
        }
    }

    @ViewBuilder
    private func cell(_ text: String, _ header: Bool, _ tag: String?) -> some View {
        let label = Text(text).fontWeight(header ? .semibold : .regular).frame(maxWidth: .infinity, alignment: .leading)
        if let tag {
            label.accessibilityIdentifier(tag)
        } else {
            label
        }
    }
}
