import PuzzlesCore
import SlideOutEngine
import SwiftData
import SwiftUI

enum SlideOutRoute: Hashable {
    case game(Int64)
    case stats
    case history
    case settings
}

struct SlideOutHomeScreen: View {
    var fixture: PuzzleRef?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: [SortDescriptor(\SlideOutGameRecord.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)])
    private var games: [SlideOutGameRecord]
    @State private var route: SlideOutRoute?
    @State private var resumeChoice: SlideOutGameRecord?
    @State private var starting = false
    @State private var failed = false
    @State private var fixtureStarted = false

    private var colors: SlideColors { SlideColors.of(scheme) }

    private var inProgress: [SlideOutGameRecord] {
        games.filter { $0.gameStatus == .inProgress }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SlideOutHero(accent: colors.accent)
                if let latest = inProgress.first {
                    continueCard(latest)
                }
                dailySection
                levelSection
            }
            .padding(16)
        }
        .slideOutScreen()
        .overlay { dialogs }
        .navigationDestination(item: $route) { route in
            destination(route).modelContainer(SlideOutStore.container)
        }
        .task {
            if let fixture, !fixtureStarted {
                fixtureStarted = true
                route = .game(SlideOutStore.start(fixture))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            SlideOutBackButton { dismiss() }
            Text("Slide Out").font(.largeTitle).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            SlideOutIconButton(systemName: "chart.bar", label: "Stats", id: "stats") { route = .stats }
            SlideOutIconButton(systemName: "clock.arrow.circlepath", label: "History", id: "history") {
                route = .history
            }
            SlideOutIconButton(systemName: "gearshape", label: "Settings", id: "settings") { route = .settings }
        }
    }

    private func continueCard(_ game: SlideOutGameRecord) -> some View {
        Button {
            route = .game(game.id)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 48, height: 48)
                    .background(colors.accent, in: Circle())
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text("\(game.title) · \(formatDuration(game.elapsedMs))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(colors.accent.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private var dailySection: some View {
        let today = CalendarDay.slideOutToday
        let left = Set(SlideOutStore.dailiesLeft(today: today))
        return SlideOutSection(title: "Today", aside: today.slideOutDayMonth) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(Level.allCases, id: \.self) { level in
                    dailyTile(level, done: !left.contains(level), today: today)
                }
            }
        }
    }

    private func dailyTile(_ level: Level, done: Bool, today: CalendarDay) -> some View {
        Button {
            openDaily(level, today: today)
        } label: {
            VStack(spacing: 4) {
                Text(level.label).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                if done {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(colors.accent)
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(done ? colors.accent.opacity(0.16) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(done ? colors.accent.opacity(0.5) : Color.primary.opacity(0.12))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily_\(level.name.lowercased())")
    }

    private var levelSection: some View {
        SlideOutSection(title: "New puzzle") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array(Level.allCases.enumerated()), id: \.element) { rank, level in
                    levelTile(level, rank: rank)
                }
            }
        }
    }

    private func levelTile(_ level: Level, rank: Int) -> some View {
        let saved = inProgress.first { $0.ref?.isDaily == false && $0.level == level.name }
        return Button {
            if let saved {
                resumeChoice = saved
            } else {
                begin { try await SlideOutBank.shared.random(level) }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(level.label).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(0..<Level.allCases.count, id: \.self) { index in
                            Capsule()
                                .fill(index <= rank ? colors.accent : Color.primary.opacity(0.14))
                                .frame(width: 12, height: 6)
                        }
                    }
                    if let saved {
                        HStack(spacing: 6) {
                            Circle().fill(colors.accent).frame(width: 6, height: 6)
                            Text("In progress · \(formatDuration(saved.elapsedMs))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(
                    saved == nil ? Color.primary.opacity(0.12) : colors.accent.opacity(0.5)
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("level_\(level.name.lowercased())")
    }

    @ViewBuilder
    private var dialogs: some View {
        if let saved = resumeChoice {
            SlideOutDialog(id: "resume_dialog", onDismiss: { resumeChoice = nil }) {
                Text(saved.title).font(.title2)
                Text("You have a puzzle in progress (\(formatDuration(saved.elapsedMs))).")
            } buttons: {
                Button("New puzzle") {
                    let level = Level.named(saved.level)
                    resumeChoice = nil
                    begin { try await SlideOutBank.shared.random(level) }
                }
                .accessibilityIdentifier("new_game")
                Button("Resume") {
                    resumeChoice = nil
                    route = .game(saved.id)
                }
                .accessibilityIdentifier("resume_game")
            }
        } else if failed {
            SlideOutDialog(id: "load_failed_dialog", onDismiss: { failed = false }) {
                Text("Couldn't load that puzzle.")
            } buttons: {
                Button("OK") { failed = false }
            }
        }
    }

    @ViewBuilder
    private func destination(_ target: SlideOutRoute) -> some View {
        switch target {
        case .game(let id):
            SlideOutGameScreen(gameId: id, onOpenGame: { route = .game($0) }, onHome: { route = nil })
        case .stats:
            SlideOutStatsScreen { route = nil }
        case .history:
            SlideOutHistoryScreen(onOpenGame: { route = .game($0) }, onBack: { route = nil })
        case .settings:
            SettingsHubView(initial: .slideOut) { route = nil }
        }
    }

    private func openDaily(_ level: Level, today: CalendarDay) {
        let id = PuzzleRef.dailyId(date: today, level: level)
        if let open = inProgress.first(where: { $0.puzzleId == id }) {
            route = .game(open.id)
        } else {
            begin { try await SlideOutBank.shared.daily(level, date: today) }
        }
    }

    private func begin(_ make: @escaping () async throws -> PuzzleRef) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            defer { starting = false }
            do {
                route = .game(SlideOutStore.start(try await make()))
            } catch {
                failed = true
            }
        }
    }
}
