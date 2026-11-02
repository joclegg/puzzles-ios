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

    @State private var filter: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History").font(.largeTitle.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", selected: filter == nil, tag: "filter_all") { filter = nil }
                    ForEach(sizes, id: \.self) { size in
                        chip("\(size)", selected: filter == size, tag: "filter_\(size)") { filter = size }
                    }
                }
            }
            let games = store.history.filter { filter == nil || $0.size == filter }
            if games.isEmpty {
                Text("No games yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(TwoToneColors.accent.opacity(0.08), in: .rect(cornerRadius: 16))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(games, id: \.uuid) { game in
                            item(game)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(TwoToneColors.accent.opacity(0.08), in: .rect(cornerRadius: 16))
            }
        }
        .padding(16)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ label: String, selected: Bool, tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? TwoToneColors.accent : TwoToneColors.accent.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func item(_ game: TwoToneGameRecord) -> some View {
        let status = game.gameStatus
        return Button {
            if status == .inProgress {
                onOpen(game.id)
            } else if let id = store.replay(game) {
                onOpen(id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(game.title).font(.subheadline.weight(.semibold))
                    Text(Theme.historyDate(ms: game.startedAt)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatDuration(game.elapsedMs))
                    Text(game.hints > 0 ? "\(status.label) · \(game.hints) hints" : status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history_item")
    }
}
