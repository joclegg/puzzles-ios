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
                .padding(16)
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

struct SightlinesHistoryView: View {
    let onOpenGame: (Int64) -> Void
    private let store = SightlinesStore.shared
    @State private var filter: Int?

    private var games: [SavedGame] {
        store.games.filter { filter == nil || $0.ref.size == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", nil, tag: "filter_all")
                    ForEach(sizes, id: \.self) { chip("\($0)", $0, tag: "filter_\($0)") }
                }
            }
            if games.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(SightlinesColors.accent)
                    Text("No games yet.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
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
                .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.tileBorder))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ label: String, _ value: Int?, tag: String) -> some View {
        Button {
            filter = value
        } label: {
            Text(label)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(filter == value ? Color(uiColor: .systemBackground) : Color.primary)
                .background(filter == value ? SightlinesColors.accent : SightlinesColors.tile, in: Capsule())
                .overlay(Capsule().stroke(filter == value ? SightlinesColors.accent : SightlinesColors.tileBorder))
        }
        .accessibilityIdentifier(tag)
    }

    private func item(_ game: SavedGame) -> some View {
        Button {
            open(game)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(game.ref.title).font(.subheadline.weight(.medium))
                    Text(started(game)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatDuration(ms: game.elapsedMs))
                    Text(game.hints > 0 ? "\(game.status.label) · \(game.hints) hints" : game.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history_item")
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

    private func started(_ game: SavedGame) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.dateFormat = "d MMM yyyy, HH:mm"
        return format.string(from: Date(timeIntervalSince1970: Double(game.startedAt) / 1000))
    }
}
