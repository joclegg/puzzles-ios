import SwiftUI
import WordWheelEngine

struct WordWheelStatsView: View {
    private let repository = WordWheelRepository.shared

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
                    ForEach(repository.stats, id: \.level) { stats in
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

    @State private var filter: Level?

    private let repository = WordWheelRepository.shared

    private static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    var body: some View {
        let games = repository.history.filter { filter == nil || $0.ref.level == filter }
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", selected: filter == nil) { filter = nil }
                    ForEach(Level.allCases, id: \.self) { level in
                        chip("\(level.letters)", selected: filter == level) { filter = level }
                            .accessibilityIdentifier("filter_\(level.letters)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .fixedSize(horizontal: false, vertical: true)
            if games.isEmpty {
                ContentUnavailableView("No games yet.", systemImage: "clock")
            } else {
                List(games) { game in
                    Button {
                        open(game)
                    } label: {
                        row(game)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("history_item")
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 8)
        .navigationTitle("History")
    }

    private func open(_ game: SavedGame) {
        if game.status == .inProgress {
            onOpenGame(game.id)
        } else {
            onOpenGame(repository.start(game.ref))
        }
    }

    private func row(_ game: SavedGame) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(game.ref.title).font(.subheadline.weight(.semibold))
                Text(Self.dateFormat.string(from: Date(timeIntervalSince1970: Double(game.startedAt) / 1000)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatDuration(game.elapsedMs))
                Text("\(game.status.label) · \(game.found.count) words, \(game.bonus.count) bonus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(selected ? WheelColors.accent.opacity(0.2) : Color.clear, in: Capsule())
                .overlay { Capsule().stroke(WheelColors.accent.opacity(selected ? 0.8 : 0.3), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

struct WordWheelSettingsView: View {
    @AppStorage(WordWheelSetting.showTimer) private var showTimer = true
    @AppStorage(WordWheelSetting.showBonusCount) private var showBonusCount = true
    @AppStorage(WordWheelSetting.showHints) private var showHints = true
    @AppStorage(WordWheelSetting.showTutorial) private var showTutorial = true
    @AppStorage(WordWheelSetting.allowReveal) private var allowReveal = true

    var body: some View {
        Form {
            row($showTimer, "show_timer", "Show the timer")
            row($showBonusCount, "show_bonus_count", "Show the bonus word count")
            row($showHints, "show_hints", "Hints", detail: "Show the hint button.")
            row(
                $showTutorial,
                "show_tutorial",
                "How to play",
                detail: "Show the ? button with the rules and a walkthrough."
            )
            row($allowReveal, "allow_reveal", "Show solution", detail: "Offer Show solution in the game menu.")
        }
        .navigationTitle("Settings")
    }

    private func row(_ value: Binding<Bool>, _ tag: String, _ title: String, detail: String? = nil) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("setting_\(tag)")
    }
}
