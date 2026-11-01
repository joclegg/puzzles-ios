import PuzzlesCore
import SlideOutEngine
import SwiftData
import SwiftUI

struct SlideOutStatsScreen: View {
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

struct SlideOutHistoryScreen: View {
    let onOpenGame: (Int64) -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Query(sort: [SortDescriptor(\SlideOutGameRecord.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)])
    private var games: [SlideOutGameRecord]
    @State private var filter: Level?

    private var shown: [SlideOutGameRecord] {
        games.filter { filter == nil || $0.level == filter?.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                SlideOutBackButton(action: onBack)
                Text("History").font(.title)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", level: nil, id: "")
                    ForEach(Level.allCases, id: \.self) { level in
                        chip(String(level.label.prefix(1)), level: level, id: "filter_\(level.name.lowercased())")
                    }
                }
            }
            if shown.isEmpty {
                empty
            } else {
                ScrollView {
                    SlideOutPanel {
                        ForEach(shown) { game in
                            item(game)
                            Divider()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .slideOutScreen()
    }

    private var empty: some View {
        let accent = SlideColors.of(scheme).accent
        return VStack(spacing: 12) {
            PuzzleIcon.image("clock.arrow.circlepath")
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.14), in: Circle())
            Text("No games yet.").foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.12)))
    }

    private func chip(_ label: String, level: Level?, id: String) -> some View {
        let accent = SlideColors.of(scheme).accent
        let selected = filter == level
        return Button {
            filter = level
        } label: {
            Text(label)
                .fontWeight(.medium)
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(selected ? accent : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(selected ? accent : Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func item(_ game: SlideOutGameRecord) -> some View {
        Button {
            open(game)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(game.title).font(.subheadline).fontWeight(.medium)
                    Text(Date(timeIntervalSince1970: Double(game.startedAt) / 1000), format: dateStyle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatDuration(game.elapsedMs))
                    Text("\(game.gameStatus.label) · \(game.moveCount) moves")
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

struct SlideOutSettingsScreen: View {
    let onBack: () -> Void

    @AppStorage(SlideOutSettingKey.showTimer) private var showTimer = true
    @AppStorage(SlideOutSettingKey.showPar) private var showPar = true
    @AppStorage(SlideOutSettingKey.showHints) private var showHints = false
    @AppStorage(SlideOutSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SlideOutSettingKey.allowReveal) private var allowReveal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 12) {
                    row("Show the timer", nil, $showTimer, "setting_show_timer")
                    row("Show par", "The fewest moves the puzzle can be solved in.", $showPar, "setting_show_par")
                    row("Hints", "Show the hint button.", $showHints, "setting_show_hints")
                    row(
                        "How to play",
                        "Show the ? button with the rules and a walkthrough.",
                        $showTutorial,
                        "setting_show_tutorial"
                    )
                    row("Show solution", "Offer Show solution in the game menu.", $allowReveal, "setting_allow_reveal")
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2)))
            }
            .padding(16)
        }
        .slideOutScreen()
    }

    private func row(_ title: String, _ detail: String?, _ value: Binding<Bool>, _ id: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().accessibilityIdentifier(id)
        }
    }
}
