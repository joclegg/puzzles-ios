import PuzzlesCore
import SightlinesEngine
import SwiftUI

struct SightlinesStatsView: View {
    private let store = SightlinesStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                StatsTable(
                    header: ["Size", "Solved", "Best", "Average"],
                    rows: sizes.map { size in
                        let stats = store.games.stats(size: size)
                        return StatsRow.size(
                            size, label: sizeLabel(size), solved: stats.solved, played: stats.played, bestMs: stats.bestMs,
                            averageMs: stats.averageMs)
                    }
                )
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
}
