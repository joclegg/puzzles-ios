import KakuroEngine
import PuzzlesCore
import SwiftUI

struct KakuroStatsView: View {
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                KakuroScreenTitle(title: "Stats", onBack: onBack)
                StatsTable(
                    header: ["Size", "Solved", "Best", "Average"],
                    rows: KakuroStore.shared.stats().map {
                        StatsRow.size(
                            $0.size, label: sizeLabel($0.size), solved: $0.solved, played: $0.played, bestMs: $0.bestMs,
                            averageMs: $0.averageMs)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .modifier(KakuroTileStyle(accent: KakuroColors.of(scheme).accent, corner: 24))
                Text("Solved out of played. Abandoned puzzles count as played. Daily puzzles count under their size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}

struct KakuroHistoryView: View {
    let navigator: KakuroNavigator
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var accent: Color {
        KakuroColors.of(scheme).accent
    }

    var body: some View {
        GameHistoryView(
            filters: sizes,
            label: { "\($0)" },
            games: { filter in KakuroStore.shared.games.filter { filter == nil || $0.ref.size == filter } },
            header: {
                KakuroScreenTitle(title: "History", onBack: onBack)
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
                        .modifier(KakuroTileStyle(accent: accent, corner: 24))
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
