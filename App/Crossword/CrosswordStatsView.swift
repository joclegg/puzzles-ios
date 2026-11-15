import CrosswordEngine
import PuzzlesCore
import SwiftUI

struct CrosswordStatsView: View {
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                CrosswordScreenTitle(title: "Stats", onBack: onBack)
                StatsTable(
                    header: ["Size", "Solved", "Best", "Average"],
                    rows: CrosswordStore.shared.stats().map {
                        StatsRow.size(
                            $0.size, label: sizeName($0.size), solved: $0.solved, played: $0.played, bestMs: $0.bestMs,
                            averageMs: $0.averageMs)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .modifier(CrosswordTileStyle(accent: CrosswordColors.of(scheme).accent, corner: 24))
                Text("Solved out of played. Abandoned puzzles count as played. Daily puzzles count under their size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}

struct CrosswordHistoryView: View {
    let navigator: CrosswordNavigator
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var accent: Color {
        CrosswordColors.of(scheme).accent
    }

    var body: some View {
        GameHistoryView(
            filters: sizes,
            label: sizeName,
            games: { filter in CrosswordStore.shared.games.filter { filter == nil || $0.ref.size == filter } },
            header: {
                CrosswordScreenTitle(title: "History", onBack: onBack)
            },
            chip: chip,
            empty: {
                HistoryEmptyState(accent: accent)
                Spacer()
            },
            rows: { history in
                ScrollView {
                    HistoryRows(history, id: \.id, row: item)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .modifier(CrosswordTileStyle(accent: accent, corner: 24))
                }
            }
        )
        .padding(16)
    }

    private func chip(_ chip: HistoryFilterChip<Int>) -> some View {
        let selected = chip.isSelected
        return Button(action: chip.select) {
            Text(chip.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? accent : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(selected ? accent : Color.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(chip.value.map { "filter_\($0)" } ?? chip.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func statusText(_ game: SavedGame) -> String {
        let status =
            switch game.status {
            case .solved: "Solved"
            case .inProgress: "In progress"
            case .abandoned: "Abandoned"
            case .revealed: "Solution shown"
            }
        return game.hints > 0 ? "\(status) · \(game.hints) hints" : status
    }

    private func item(_ game: SavedGame) -> some View {
        HistoryItemButton {
            if game.status == .inProgress {
                navigator.open(game)
            } else {
                navigator.start(game.ref)
            }
        } label: {
            HistoryRowLabel(
                title: game.ref.title,
                date: Theme.historyDate(ms: game.startedAt),
                elapsedMs: game.elapsedMs,
                detail: statusText(game),
                spacing: 2
            )
        }
    }
}
