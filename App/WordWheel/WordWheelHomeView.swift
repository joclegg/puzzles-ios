import PuzzlesCore
import SwiftUI
import WordWheelEngine

struct WordWheelHomeView: View {
    var fixture: PuzzleRef?

    @State private var openGame: Int64?
    @State private var showStats = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var resumeChoice: SavedGame?
    @State private var starting = false
    @State private var fixtureOpened = false

    private let repository = WordWheelRepository.shared

    var body: some View {
        content
            .navigationTitle("Word Wheel")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    DailyCalendarButton(tab: .wordWheel)
                    toolbarButton("chart.bar", "Stats", "stats") { showStats = true }
                    toolbarButton("clock", "History", "history") { showHistory = true }
                    toolbarButton("gearshape", "Settings", "settings") { showSettings = true }
                }
            }
            .navigationDestination(item: $openGame) { id in
                WordWheelGameView(
                    id: id,
                    onOpenGame: { openGame = $0 },
                    onHome: { openGame = nil }
                )
                .id(id)
            }
            .navigationDestination(isPresented: $showStats) {
                WordWheelStatsView()
            }
            .navigationDestination(isPresented: $showHistory) {
                WordWheelHistoryView { id in
                    showHistory = false
                    openGame = id
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsHubView(initial: .wordWheel)
            }
            .overlay {
                if let saved = resumeChoice {
                    WordWheelConfirm(
                        title: saved.ref.title,
                        message: "You have a puzzle in progress (\(formatDuration(saved.elapsedMs))).",
                        tag: "resume_dialog",
                        confirm: "Resume",
                        confirmTag: "resume_game",
                        dismiss: "New puzzle",
                        dismissTag: "new_game",
                        onConfirm: {
                            resumeChoice = nil
                            openGame = saved.id
                        },
                        onDismissButton: {
                            resumeChoice = nil
                            start(saved.ref.level)
                        },
                        onCancel: { resumeChoice = nil }
                    )
                }
            }
            .task {
                if let id = DailyRouter.shared.take(.wordWheel).flatMap(Int64.init) {
                    openGame = id
                }
                if let fixture, !fixtureOpened {
                    fixtureOpened = true
                    openGame = repository.start(fixture)
                }
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                if let latest = repository.inProgress.first {
                    continueCard(latest)
                }
                section("Today", aside: dayLabel(iso: CalendarDay.today.isoString)) {
                    let solved = repository.dailySolved(on: CalendarDay.today)
                    HStack(spacing: 8) {
                        ForEach(Level.allCases, id: \.self) { level in
                            dailyTile(level, done: solved.contains(level))
                        }
                    }
                }
                section("New puzzle") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Level.allCases, id: \.self) { level in
                            levelTile(level)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var hero: some View {
        HStack(spacing: 16) {
            WordWheelGameIcon()
            Text("Swipe the letters to fill the crossword")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [WheelColors.accent.opacity(0.2), WheelColors.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func continueCard(_ game: SavedGame) -> some View {
        Button {
            openGame = game.id
        } label: {
            HStack(spacing: 16) {
                PuzzleIcon.image("play.fill")
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 48, height: 48)
                    .background(WheelColors.accent, in: Circle())
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text("\(game.ref.title) · \(formatDuration(game.elapsedMs))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .tile(highlighted: true, radius: 24)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private func dailyTile(_ level: Level, done: Bool) -> some View {
        Button {
            launch { try await repository.openDaily(level) }
        } label: {
            VStack(spacing: 4) {
                Text(level.label).font(.subheadline.weight(.semibold)).lineLimit(1)
                if done {
                    doneBadge
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .tile(highlighted: done, radius: 16, fill: done ? WheelColors.accent.opacity(0.16) : nil)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily_\(level.letters)")
    }

    private func levelTile(_ level: Level) -> some View {
        let saved = repository.inProgress.first { !$0.ref.isDaily && $0.ref.level == level }
        return Button {
            if let saved {
                resumeChoice = saved
            } else {
                start(level)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(level.label).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(Level.allCases, id: \.self) { step in
                            Capsule()
                                .fill(step.rawValue <= level.rawValue ? WheelColors.accent : Color.primary.opacity(0.14))
                                .frame(width: 12, height: 6)
                        }
                    }
                    if let saved {
                        HStack(spacing: 6) {
                            Circle().fill(WheelColors.accent).frame(width: 6, height: 6)
                            Text("In progress · \(formatDuration(saved.elapsedMs))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.right").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .tile(highlighted: saved != nil, radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("level_\(level.letters)")
    }

    private var doneBadge: some View {
        PuzzleIcon.image("checkmark.circle.fill").foregroundStyle(WheelColors.accent)
    }

    private func section<Content: View>(
        _ title: String,
        aside: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let aside {
                    Text(aside).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    private func toolbarButton(
        _ icon: String,
        _ label: String,
        _ tag: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            PuzzleIcon.image(icon)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private func start(_ level: Level) {
        launch {
            let puzzles = try await WordWheelBank.shared.puzzles(level)
            return repository.start(.random(puzzles: puzzles, level: level, seed: Int64.random(in: .min ... .max)))
        }
    }

    private func launch(_ work: @escaping @MainActor () async throws -> Int64) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            defer { starting = false }
            if let id = try? await work() {
                openGame = id
            }
        }
    }
}

extension View {
    fileprivate func tile(highlighted: Bool, radius: CGFloat, fill: Color? = nil) -> some View {
        background(fill ?? Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(WheelColors.accent.opacity(highlighted ? 0.8 : 0.2), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct WordWheelGameIcon: View {
    private let letters: [(String, CGFloat, CGFloat)] = [
        ("W", 19, 2), ("O", 35, 19), ("R", 19, 36), ("D", 2, 19),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().fill(WheelColors.wheel)
            ForEach(letters, id: \.0) { letter, x, y in
                Text(letter)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WheelColors.chosenText)
                    .frame(width: 18, height: 18)
                    .background(WheelColors.chosen, in: Circle())
                    .offset(x: x, y: y)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}
