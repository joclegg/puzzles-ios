import PuzzlesCore
import SwiftUI
import TwoToneEngine

struct TwoToneStatsView: View {
    let store: TwoToneStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stats").font(.largeTitle.bold())
                StatsTable(
                    header: ["Size", "Solved", "Best", "Average"],
                    rows: store.stats.map {
                        StatsRow.size(
                            $0.size, label: sizeLabel($0.size), solved: $0.solved, played: $0.played, bestMs: $0.bestMs,
                            averageMs: $0.averageMs)
                    }
                )
                .padding(16)
                .background(TwoToneColors.accent.opacity(0.08), in: .rect(cornerRadius: 16))
                Text("Solved out of played. Abandoned puzzles count as played. Daily puzzles count under their size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TwoToneHistoryView: View {
    let store: TwoToneStore
    let onOpen: (Int64) -> Void

    var body: some View {
        GameHistoryView(
            filters: sizes,
            label: { "\($0)" },
            games: { filter in store.history.filter { filter == nil || $0.size == filter } },
            header: {
                Text("History").font(.largeTitle.bold())
            },
            chip: chip,
            empty: {
                Text("No games yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(TwoToneColors.accent.opacity(0.08), in: .rect(cornerRadius: 16))
                Spacer()
            },
            rows: { games in
                ScrollView {
                    HistoryRows(games, id: \.uuid, row: item)
                        .padding(.horizontal, 16)
                }
                .background(TwoToneColors.accent.opacity(0.08), in: .rect(cornerRadius: 16))
            }
        )
        .padding(16)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ chip: HistoryFilterChip<Int>) -> some View {
        let selected = chip.isSelected
        return Button(action: chip.select) {
            Text(chip.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? TwoToneColors.accent : TwoToneColors.accent.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(chip.value.map { "filter_\($0)" } ?? "filter_all")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func item(_ game: TwoToneGameRecord) -> some View {
        let status = game.gameStatus
        return HistoryItemButton {
            if status == .inProgress {
                onOpen(game.id)
            } else if let id = store.replay(game) {
                onOpen(id)
            }
        } label: {
            HistoryRowLabel(
                title: game.title,
                date: Theme.historyDate(ms: game.startedAt),
                elapsedMs: game.elapsedMs,
                detail: game.hints > 0 ? "\(status.label) · \(game.hints) hints" : status.label,
                titleFont: .subheadline.weight(.semibold)
            )
        }
    }
}
