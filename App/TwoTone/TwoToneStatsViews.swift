import SwiftUI
import TwoToneEngine

struct TwoToneStatsView: View {
    let store: TwoToneStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stats").font(.largeTitle.bold())
                VStack(spacing: 8) {
                    row("Size", "Solved", "Best", "Average", header: true, tag: nil)
                    ForEach(store.stats, id: \.size) { stats in
                        row(
                            sizeLabel(stats.size),
                            "\(stats.solved)/\(stats.played)",
                            stats.bestMs.map(formatDuration) ?? "–",
                            stats.averageMs.map(formatDuration) ?? "–",
                            header: false,
                            tag: "size_\(stats.size)"
                        )
                    }
                }
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

    private func row(_ size: String, _ solved: String, _ best: String, _ average: String, header: Bool, tag: String?) -> some View {
        HStack {
            Text(size).frame(maxWidth: .infinity, alignment: .leading)
            Text(solved).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier(tag.map { "\($0)_solved" } ?? "")
            Text(best).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier(tag.map { "\($0)_best" } ?? "")
            Text(average).frame(maxWidth: .infinity, alignment: .leading)
        }
        .fontWeight(header ? .semibold : .regular)
    }
}

struct TwoToneHistoryView: View {
    private static let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

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
        let date = Date(timeIntervalSince1970: TimeInterval(game.startedAt) / 1000)
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
                    Text(Self.dateFormat.string(from: date)).font(.caption).foregroundStyle(.secondary)
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

struct TwoToneSettingsView: View {
    @AppStorage(TwoToneSettingKey.markBrokenRules) private var markBrokenRules = true
    @AppStorage(TwoToneSettingKey.showTimer) private var showTimer = true
    @AppStorage(TwoToneSettingKey.showProgress) private var showProgress = true
    @AppStorage(TwoToneSettingKey.showHints) private var showHints = true
    @AppStorage(TwoToneSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(TwoToneSettingKey.allowReveal) private var allowReveal = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filling in").font(.headline)
                    toggle(
                        "Mark broken rules", "Outline tiles that make three in a row, overfill a line or copy another line.",
                        "setting_mark_broken_rules", $markBrokenRules)
                    toggle("Show the timer", nil, "setting_show_timer", $showTimer)
                    toggle("Show how much is filled in", nil, "setting_show_progress", $showProgress)
                    toggle("Hints", "Show the hint button.", "setting_show_hints", $showHints)
                    toggle("How to play", "Show the ? button with the rules and a walkthrough.", "setting_show_tutorial", $showTutorial)
                    toggle("Show solution", "Offer Show solution in the game menu.", "setting_allow_reveal", $allowReveal)
                }
                .padding(16)
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.4)) }
            }
            .padding(16)
        }
        .tint(TwoToneColors.accent)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ title: String, _ detail: String?, _ tag: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier(tag)
    }
}
