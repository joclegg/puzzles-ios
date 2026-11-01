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
    @State private var filter: Int?

    private var accent: Color {
        KakuroColors.of(scheme).accent
    }

    private var history: [SavedGame] {
        KakuroStore.shared.games.filter { filter == nil || $0.ref.size == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KakuroScreenTitle(title: "History", onBack: onBack)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", value: nil, tag: nil)
                    ForEach(sizes, id: \.self) { size in
                        chip("\(size)", value: size, tag: "filter_\(size)")
                    }
                }
            }
            if history.isEmpty {
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(history, id: \.id) { game in
                            item(game)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .modifier(KakuroTileStyle(accent: accent, corner: 24))
                }
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            PuzzleIcon.image("clock.arrow.circlepath")
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.14), in: Circle())
            Text("No games yet.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.12), lineWidth: 1))
    }

    private func chip(_ label: String, value: Int?, tag: String?) -> some View {
        let selected = filter == value
        return Button {
            filter = value
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? accent : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(selected ? accent : Color.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag ?? label)
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
        Button {
            if game.status == .inProgress {
                navigator.open(game)
            } else {
                navigator.start(game.ref)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.ref.title).font(.subheadline.weight(.medium))
                    Text(Theme.historyDate(ms: game.startedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(game.elapsedMs))
                    Text(statusText(game)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history_item")
    }
}
