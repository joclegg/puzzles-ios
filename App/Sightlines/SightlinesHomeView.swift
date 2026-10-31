import PuzzlesCore
import SightlinesEngine
import SwiftUI

enum SightlinesScreen: Hashable, Identifiable {
    case stats
    case history
    case settings
    case game(Int64)

    var id: Self {
        self
    }
}

struct SightlinesHomeView: View {
    var fixture: PuzzleRef?
    private let store = SightlinesStore.shared
    @State private var screen: SightlinesScreen?
    @State private var resumeChoice: SavedGame?
    @State private var starting = false
    @State private var fixtureOpened = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                if let latest = store.games.inProgress.first {
                    continueCard(latest)
                }
                section("Today", aside: dayLabel(iso: SightlinesToday.date.isoString)) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(sizes, id: \.self, content: dailyTile)
                    }
                }
                section("New puzzle", aside: nil) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(sizes, id: \.self, content: sizeTile)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Sightlines")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarButton("chart.bar", "Stats", tag: "stats", .stats)
                toolbarButton("clock.arrow.circlepath", "History", tag: "history", .history)
                toolbarButton("gearshape", "Settings", tag: "settings", .settings)
            }
        }
        .navigationDestination(item: $screen) { destination in
            switch destination {
            case .stats:
                SightlinesStatsView()
            case .history:
                SightlinesHistoryView { screen = .game($0) }
            case .settings:
                SightlinesSettingsView()
            case .game(let id):
                SightlinesGameView(id: id, onOpenGame: { screen = .game($0) }, onHome: { screen = nil }).id(id)
            }
        }
        .overlay {
            if let saved = resumeChoice {
                resumeDialog(saved)
            }
        }
        .task {
            guard let fixture, !fixtureOpened else {
                return
            }
            fixtureOpened = true
            screen = .game(await store.start { fixture })
        }
    }

    private func toolbarButton(_ icon: String, _ label: String, tag: String, _ target: SightlinesScreen) -> some View {
        Button {
            screen = target
        } label: {
            Image(systemName: icon)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 80, height: 80)
                .shadow(radius: 1)
                .overlay { SightlinesGameIcon() }
            Text("Blue dots count what they can see").foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [SightlinesColors.accent.opacity(0.2), SightlinesColors.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.accent.opacity(0.25)))
    }

    private func continueCard(_ game: SavedGame) -> some View {
        Button {
            screen = .game(game.id)
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(SightlinesColors.accent)
                    .frame(width: 48, height: 48)
                    .overlay { Image(systemName: "play.fill").foregroundStyle(Color(uiColor: .systemBackground)) }
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text("\(game.ref.title) · \(formatDuration(ms: game.elapsedMs))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(SightlinesColors.accent.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private func section<Content: View>(_ title: String, aside: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1.2)
                Spacer()
                if let aside {
                    Text(aside).font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            content()
        }
    }

    private func dailyTile(_ size: Int) -> some View {
        let done = store.games.dailySolved(date: SightlinesToday.date).contains(size)
        return Button {
            launch {
                await openDaily(size: size)
            }
        } label: {
            VStack(spacing: 4) {
                Text(sizeLabel(size)).font(.subheadline.weight(.semibold)).lineLimit(1)
                if done {
                    doneBadge
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(done ? SightlinesColors.accent.opacity(0.16) : SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(done ? SightlinesColors.accent.opacity(0.5) : SightlinesColors.tileBorder))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily_\(size)")
    }

    private var doneBadge: some View {
        Circle()
            .fill(SightlinesColors.accent)
            .frame(width: 18, height: 18)
            .overlay {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(uiColor: .systemBackground))
            }
            .accessibilityLabel("Done")
    }

    private func sizeTile(_ size: Int) -> some View {
        let saved = store.games.savedGame(forSize: size)
        return Button {
            if let saved {
                resumeChoice = saved
            } else {
                startNew(size: size)
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sizeLabel(size)).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(sizes, id: \.self) { step in
                            Capsule()
                                .fill(step <= size ? SightlinesColors.accent : Color.primary.opacity(0.14))
                                .frame(width: 12, height: 6)
                        }
                    }
                    if let saved {
                        HStack(spacing: 6) {
                            Circle().fill(SightlinesColors.accent).frame(width: 6, height: 6)
                            Text("In progress · \(formatDuration(ms: saved.elapsedMs))").font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(SightlinesColors.tile, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(saved != nil ? SightlinesColors.accent.opacity(0.5) : SightlinesColors.tileBorder)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("size_\(size)")
    }

    private func resumeDialog(_ saved: SavedGame) -> some View {
        SightlinesDialog(tag: "resume_dialog", dismiss: { resumeChoice = nil }) {
            Text(saved.ref.title).font(.title3.weight(.semibold))
            Text("You have a puzzle in progress (\(formatDuration(ms: saved.elapsedMs))).")
            HStack(spacing: 16) {
                Spacer()
                Text("New puzzle")
                    .sightlinesDialogAction("new_game") {
                        resumeChoice = nil
                        startNew(size: saved.ref.size)
                    }
                Text("Resume")
                    .sightlinesDialogAction("resume_game") {
                        resumeChoice = nil
                        screen = .game(saved.id)
                    }
            }
        }
    }

    private func startNew(size: Int) {
        launch {
            let seed = Int64.random(in: .min ... .max)
            return await store.start { PuzzleRef.random(seed: seed, size: size) }
        }
    }

    private func openDaily(size: Int) async -> Int64 {
        let date = SightlinesToday.date
        if let existing = store.games.dailyInProgress(date: date, size: size) {
            return existing.id
        }
        return await store.start { PuzzleRef.daily(date: date, size: size) }
    }

    private func launch(_ start: @escaping () async -> Int64) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            screen = .game(await start())
            starting = false
        }
    }
}
