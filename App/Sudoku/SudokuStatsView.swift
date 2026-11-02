import PuzzlesCore
import SudokuEngine
import SwiftUI

struct SudokuStatsView: View {
    @Environment(SudokuNavigator.self) private var navigator

    var body: some View {
        let bests = SudokuStore.shared.bests
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    SudokuBackButton(action: navigator.back)
                    Text("Best times").font(.title.weight(.regular))
                }
                ForEach(GameMode.allCases, id: \.self) { mode in
                    panel(mode, bests)
                }
                Text("Custom puzzles show in History but don't count towards best times.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func panel(_ mode: GameMode, _ bests: [BestTime]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode.label).font(.title2)
            row("Level", "Solved", "Best", "Average", weight: .semibold, tag: nil)
            ForEach(mode.levels, id: \.self) { level in
                let stats = bests.first { $0.mode == mode && $0.difficulty == level }
                row(
                    levelLabel(level),
                    "\(stats?.completed ?? 0)",
                    stats.map { formatDuration($0.bestMs) } ?? "–",
                    stats.flatMap { $0.completed > 0 ? formatDuration($0.averageMs) : nil } ?? "–",
                    weight: .regular,
                    tag: "best_\(mode.slug)_\(level.name.lowercased())"
                )
            }
        }
        .padding(16)
        .modifier(SudokuTileStyle())
    }

    private func row(
        _ level: String, _ solved: String, _ best: String, _ average: String, weight: Font.Weight, tag: String?
    ) -> some View {
        HStack {
            Text(level).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1.3)
            Text(solved).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(tag.map { "\($0)_solved" } ?? "")
            Text(best).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(tag.map { "\($0)_best" } ?? "")
            Text(average).frame(maxWidth: .infinity, alignment: .leading)
        }
        .fontWeight(weight)
    }
}

enum SudokuHistoryFilter: String, CaseIterable {
    case classic, killer, custom

    func matches(_ game: SudokuSavedGame) -> Bool {
        switch self {
        case .custom:
            game.ref.custom
        case .classic:
            !game.ref.custom && game.ref.mode == .classic
        case .killer:
            !game.ref.custom && game.ref.mode == .killer
        }
    }
}

struct SudokuHistoryView: View {
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        GameHistoryView(
            filters: SudokuHistoryFilter.allCases,
            label: { $0.rawValue.capitalized },
            games: { filter in SudokuStore.shared.history.filter { filter?.matches($0) ?? true } },
            header: {
                HStack(spacing: 0) {
                    SudokuBackButton(action: navigator.back)
                    Text("History").font(.title.weight(.regular))
                }
            },
            chip: chip,
            empty: {
                Text("No games yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .modifier(SudokuTileStyle())
            },
            rows: { games in
                ScrollView {
                    HistoryRows(games, id: \.id, row: item)
                        .padding(.horizontal, 12)
                }
                .modifier(SudokuTileStyle())
            }
        )
        .padding(16)
    }

    private func chip(_ chip: HistoryFilterChip<SudokuHistoryFilter>) -> some View {
        let selected = chip.isSelected
        return Button(action: chip.select) {
            Text(chip.label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? palette.accent.opacity(0.16) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(selected ? palette.accent : palette.thinLine))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(chip.value.map { "filter_\($0.rawValue)" } ?? "filter_all")
    }

    private func item(_ game: SudokuSavedGame) -> some View {
        HistoryItemButton {
            if game.status == .inProgress {
                navigator.openGame(game.id)
            } else {
                let replay = SudokuStore.shared.start(game.ref, mistakeCheck: sudokuModeSettings(game.ref.mode).mistakeCheck)
                navigator.openGame(replay.id)
            }
        } label: {
            HistoryRowLabel(
                title: game.title,
                date: Self.date(game.startedAt),
                elapsedMs: game.elapsedMs,
                detail: game.mistakeCheck != .off ? "\(game.status.label) · \(game.mistakes) mistakes" : game.status.label
            )
        }
    }

    private static func date(_ ms: Int64) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
