import PuzzlesCore
import SolitaireEngine
import SwiftUI

struct SolitaireStatsView: View {
    let store: SolitaireStore
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    SolitaireBackButton(action: onBack)
                    Text("Stats").font(.largeTitle)
                }
                ForEach(store.stats(), id: \.drawMode) { mode in
                    panel(mode)
                }
                Text("Abandoned deals count as played. Daily deals count under the draw mode they were played with.")
                    .font(.caption)
                    .foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
            .padding(16)
        }
        .solitaireScreen()
    }

    private func panel(_ mode: DrawStats) -> some View {
        let tag = mode.drawMode.tagName
        return VStack(alignment: .leading, spacing: 8) {
            Text(mode.drawMode.label).font(.title2)
            row("Played", "\(mode.played)", tag: "\(tag)_played")
            row("Won", "\(mode.won)", tag: "\(tag)_won")
            row("Win rate", mode.winRate, tag: "\(tag)_win_rate")
            row("Best time", mode.bestMs.map(formatDuration) ?? "–", tag: "\(tag)_best")
            row("Average time", mode.averageMs.map(formatDuration) ?? "–", tag: "\(tag)_average")
            row("Fewest moves", mode.fewestMoves.map(String.init) ?? "–", tag: "\(tag)_fewest_moves")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, tag: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).accessibilityIdentifier(tag)
        }
    }
}

struct SolitaireHistoryView: View {
    let store: SolitaireStore
    let onOpenGame: (Int64) -> Void
    let onBack: () -> Void

    var body: some View {
        GameHistoryView(
            filters: DrawMode.allCases,
            label: \.label,
            chipsPadding: EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1),
            games: { store.history(filter: $0) },
            header: {
                HStack(spacing: 0) {
                    SolitaireBackButton(action: onBack)
                    Text("History").font(.largeTitle)
                }
            },
            chip: chip,
            empty: {
                Text("No games yet.")
                    .foregroundStyle(SolitaireColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, minHeight: 120)
                Spacer(minLength: 0)
            },
            rows: { games in
                ScrollView {
                    HistoryRows(games, id: \.id, row: item)
                        .padding(.horizontal, 16)
                }
                .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
            }
        )
        .padding(16)
        .solitaireScreen()
    }

    private func chip(_ chip: HistoryFilterChip<DrawMode>) -> some View {
        Button(action: chip.select) {
            Text(chip.label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(chip.isSelected ? SolitaireColors.accent.opacity(0.2) : .clear, in: Capsule())
                .overlay(Capsule().stroke(SolitaireColors.accent.opacity(chip.isSelected ? 1 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(chip.value.map { "filter_\($0.tagName)" } ?? "filter_all")
    }

    private func item(_ game: SavedGame) -> some View {
        HistoryRowLabel(
            title: game.deal.title,
            date: Theme.historyDate(ms: game.startedAt),
            elapsedMs: game.elapsedMs,
            detail: game.summary,
            secondary: AnyShapeStyle(SolitaireColors.onSurfaceVariant)
        )
        .onTapGesture {
            if game.status == .inProgress {
                onOpenGame(game.id)
            } else {
                onOpenGame(store.start(game.deal).id)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history_item")
    }
}
