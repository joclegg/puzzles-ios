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

struct SightlinesHistoryView: View {
    let onOpenGame: (Int64) -> Void
    private let store = SightlinesStore.shared

    var body: some View {
        GameHistoryView(
            filters: sizes,
            label: { "\($0)" },
            games: { filter in store.games.filter { filter == nil || $0.ref.size == filter } },
            header: {},
            chip: chip,
            empty: {
                HistoryEmptyState(accent: SightlinesColors.accent, border: SightlinesColors.tileBorder)
                Spacer(minLength: 0)
            },
            rows: { games in
                ScrollView {
                    HistoryRows(games, id: \.id, row: item)
                        .padding(.horizontal, 16)
                }
                .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
                Spacer(minLength: 0)
            }
        )
        .padding(16)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ chip: HistoryFilterChip<Int>) -> some View {
        Button(action: chip.select) {
            Text(chip.label)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(chip.isSelected ? Color(uiColor: .systemBackground) : Color.primary)
                .background(chip.isSelected ? SightlinesColors.accent : SightlinesColors.tile, in: Capsule())
                .overlay(Capsule().stroke(chip.isSelected ? SightlinesColors.accent : SightlinesColors.tileBorder))
        }
        .accessibilityIdentifier(chip.value.map { "filter_\($0)" } ?? "filter_all")
    }

    private func item(_ game: SavedGame) -> some View {
        HistoryItemButton {
            open(game)
        } label: {
            HistoryRowLabel(
                title: game.ref.title,
                date: Theme.historyDate(ms: game.startedAt),
                elapsedMs: game.elapsedMs,
                detail: game.hints > 0 ? "\(game.status.label) · \(game.hints) hints" : game.status.label
            )
        }
    }

    private func open(_ game: SavedGame) {
        if game.status == .inProgress {
            onOpenGame(game.id)
            return
        }
        let ref = game.ref
        Task {
            onOpenGame(await store.start { ref })
        }
    }
}
