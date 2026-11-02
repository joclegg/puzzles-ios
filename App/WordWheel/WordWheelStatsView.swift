import PuzzlesCore
import SwiftUI
import WordWheelEngine

struct WordWheelStatsView: View {
    private let store = WordWheelStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Grid(alignment: .leading, verticalSpacing: 8) {
                    GridRow {
                        Text("Letters").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Solved").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Bonus").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Best").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fontWeight(.semibold)
                    ForEach(store.stats, id: \.level) { stats in
                        let tag = "level_\(stats.level.letters)"
                        GridRow {
                            Text(stats.level.label)
                            Text("\(stats.solved)/\(stats.played)")
                                .accessibilityIdentifier("\(tag)_solved")
                            Text("\(stats.bonusWords)")
                                .accessibilityIdentifier("\(tag)_best")
                            Text(stats.bestMs.map(formatDuration) ?? "–")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(WheelColors.accent.opacity(0.2), lineWidth: 1) }
                Text("Solved out of played. Bonus counts every extra word you found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Stats")
    }
}

struct WordWheelHistoryView: View {
    let onOpenGame: (Int64) -> Void

    private let store = WordWheelStore.shared

    private static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    var body: some View {
        GameHistoryView(
            filters: Level.allCases,
            label: { "\($0.letters)" },
            chipsPadding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16),
            fixedChipsHeight: true,
            games: { filter in store.history.filter { filter == nil || $0.ref.level == filter } },
            header: {},
            chip: chip,
            empty: {
                ContentUnavailableView("No games yet.", systemImage: "clock")
            },
            rows: { games in
                List(games) { game in
                    HistoryItemButton {
                        open(game)
                    } label: {
                        row(game)
                    }
                }
                .listStyle(.plain)
            }
        )
        .padding(.top, 8)
        .navigationTitle("History")
    }

    private func open(_ game: SavedGame) {
        if game.status == .inProgress {
            onOpenGame(game.id)
        } else {
            onOpenGame(store.start(game.ref))
        }
    }

    private func row(_ game: SavedGame) -> some View {
        HistoryRowLabel(
            title: game.ref.title,
            date: Self.dateFormat.string(from: Date(timeIntervalSince1970: Double(game.startedAt) / 1000)),
            elapsedMs: game.elapsedMs,
            detail: "\(game.status.label) · \(game.found.count) words, \(game.bonus.count) bonus",
            titleFont: .subheadline.weight(.semibold),
            verticalPadding: 0
        )
    }

    @ViewBuilder
    private func chip(_ chip: HistoryFilterChip<Level>) -> some View {
        let button = Button(action: chip.select) {
            Text(chip.label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(chip.isSelected ? WheelColors.accent.opacity(0.2) : Color.clear, in: Capsule())
                .overlay { Capsule().stroke(WheelColors.accent.opacity(chip.isSelected ? 0.8 : 0.3), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        if let level = chip.value {
            button.accessibilityIdentifier("filter_\(level.letters)")
        } else {
            button
        }
    }
}
