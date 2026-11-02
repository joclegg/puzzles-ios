import PuzzlesCore
import SlideOutEngine
import SwiftData
import SwiftUI

struct SlideOutStatsView: View {
    let onBack: () -> Void

    @Query private var games: [SlideOutGameRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    SlideOutBackButton(action: onBack)
                    Text("Stats").font(.title)
                }
                SlideOutPanel {
                    row("Level", "Solved", "At par", "Best", tag: nil).fontWeight(.semibold)
                    ForEach(LevelStats.of(games.map(\.finishedGame)), id: \.level) { stats in
                        row(
                            stats.level.label,
                            "\(stats.solved)/\(stats.played)",
                            "\(stats.atPar)",
                            stats.bestMs.map(formatDuration) ?? "–",
                            tag: "level_\(stats.level.name.lowercased())"
                        )
                    }
                }
                Text("Solved out of played. At par means solved in the fewest possible moves.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .slideOutScreen()
    }

    private func row(_ level: String, _ solved: String, _ atPar: String, _ best: String, tag: String?) -> some View {
        HStack {
            Text(level).frame(maxWidth: .infinity, alignment: .leading)
            Text(solved)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(tag.map { "\($0)_solved" } ?? "")
            Text(atPar)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(tag.map { "\($0)_best" } ?? "")
            Text(best).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SlideOutHistoryView: View {
    let onOpenGame: (Int64) -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Query(sort: [SortDescriptor(\SlideOutGameRecord.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)])
    private var games: [SlideOutGameRecord]

    var body: some View {
        GameHistoryView(
            filters: Level.allCases,
            label: { String($0.label.prefix(1)) },
            games: { filter in games.filter { filter == nil || $0.level == filter?.name } },
            header: {
                HStack(spacing: 0) {
                    SlideOutBackButton(action: onBack)
                    Text("History").font(.title)
                }
            },
            chip: chip,
            empty: {
                HistoryEmptyState(accent: SlideColors.of(scheme).accent)
                Spacer(minLength: 0)
            },
            rows: { shown in
                ScrollView {
                    SlideOutPanel {
                        ForEach(shown) { game in
                            item(game)
                            Divider()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        )
        .padding(16)
        .slideOutScreen()
    }

    private func chip(_ chip: HistoryFilterChip<Level>) -> some View {
        let accent = SlideColors.of(scheme).accent
        let selected = chip.isSelected
        return Button(action: chip.select) {
            Text(chip.label)
                .fontWeight(.medium)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(selected ? accent : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(selected ? accent : Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(chip.value.map { "filter_\($0.name.lowercased())" } ?? "")
    }

    private func item(_ game: SlideOutGameRecord) -> some View {
        HistoryItemButton {
            open(game)
        } label: {
            HistoryRowLabel(
                title: game.title,
                date: Date(timeIntervalSince1970: Double(game.startedAt) / 1000).formatted(dateStyle),
                elapsedMs: game.elapsedMs,
                detail: "\(game.gameStatus.label) · \(game.moveCount) moves"
            )
        }
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .year()
            .hour(.twoDigits(amPM: .omitted))
            .minute()
    }

    private func open(_ game: SlideOutGameRecord) {
        if game.gameStatus == .inProgress {
            onOpenGame(game.id)
        } else if let ref = game.ref {
            onOpenGame(SlideOutStore.start(ref))
        }
    }
}
