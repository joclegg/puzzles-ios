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
    @State private var filter: DrawMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                SolitaireBackButton(action: onBack)
                Text("History").font(.largeTitle)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", selected: filter == nil, tag: "filter_all") { filter = nil }
                    ForEach(DrawMode.allCases, id: \.self) { mode in
                        chip(mode.label, selected: filter == mode, tag: "filter_\(mode.tagName)") { filter = mode }
                    }
                }
                .padding(1)
            }
            let games = store.history(filter: filter)
            if games.isEmpty {
                Text("No games yet.")
                    .foregroundStyle(SolitaireColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, minHeight: 120)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(games) { game in
                            item(game)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
            }
        }
        .padding(16)
        .solitaireScreen()
    }

    private func chip(_ label: String, selected: Bool, tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? SolitaireColors.accent.opacity(0.2) : .clear, in: Capsule())
                .overlay(Capsule().stroke(SolitaireColors.accent.opacity(selected ? 1 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag)
    }

    private func item(_ game: SavedGame) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(game.deal.title).font(.subheadline.weight(.medium))
                Text(Self.date(game.startedAt)).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatDuration(game.elapsedMs))
                Text(game.summary).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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

    private static func date(_ ms: Int64) -> String {
        Theme.historyDate(ms: ms)
    }
}
