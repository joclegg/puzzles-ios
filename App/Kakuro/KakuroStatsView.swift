import KakuroEngine
import SwiftUI

struct KakuroStatsView: View {
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                KakuroScreenTitle(title: "Stats", onBack: onBack)
                VStack(spacing: 8) {
                    row("Size", "Solved", "Best", "Average", header: true, tag: nil)
                    ForEach(KakuroStore.shared.stats(), id: \.size) { stats in
                        row(
                            sizeLabel(stats.size),
                            "\(stats.solved)/\(stats.played)",
                            stats.bestMs.map { formatDuration(ms: $0) } ?? "–",
                            stats.averageMs.map { formatDuration(ms: $0) } ?? "–",
                            header: false,
                            tag: "size_\(stats.size)"
                        )
                    }
                }
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

    private func row(_ size: String, _ solved: String, _ best: String, _ average: String, header: Bool, tag: String?) -> some View {
        HStack {
            cell(size, header: header, tag: nil)
            cell(solved, header: header, tag: tag.map { "\($0)_solved" })
            cell(best, header: header, tag: tag.map { "\($0)_best" })
            cell(average, header: header, tag: nil)
        }
    }

    @ViewBuilder
    private func cell(_ text: String, header: Bool, tag: String?) -> some View {
        let label = Text(text)
            .fontWeight(header ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        if let tag {
            label.accessibilityIdentifier(tag)
        } else {
            label
        }
    }
}

struct KakuroHistoryView: View {
    let navigator: KakuroNavigator
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var filter: Int?

    private static let dateFormat: DateFormatter = {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_GB")
        format.dateFormat = "d MMM yyyy, HH:mm"
        return format
    }()

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
            Image(systemName: "clock.arrow.circlepath")
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
                    Text(Self.dateFormat.string(from: Date(timeIntervalSince1970: Double(game.startedAt) / 1000)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(ms: game.elapsedMs))
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
