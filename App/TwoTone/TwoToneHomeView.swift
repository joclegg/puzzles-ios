import PuzzlesCore
import SwiftUI
import TwoToneEngine

enum TwoToneRoute: Hashable {
    case game(Int64)
    case stats
    case history
    case settings
}

struct TwoToneHomeView: View {
    var fixture: PuzzleRef?

    @State private var store = TwoToneStore.shared
    @State private var route: TwoToneRoute?
    @State private var starting = false
    @State private var fixtureOpened = false
    @State private var resumeChoice: TwoToneGameRecord?

    var body: some View {
        let today = CalendarDay.today
        let inProgress = store.inProgress
        let solved = store.dailySolved(date: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hero
                if let latest = inProgress.first {
                    continueCard(latest)
                }
                section("Today", aside: dayMonthLabel(iso: today.isoString)) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(sizes, id: \.self) { size in
                            dailyTile(size, done: solved.contains(size), today: today)
                        }
                    }
                }
                section("New puzzle", aside: nil) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(Array(sizes.enumerated()), id: \.element) { index, size in
                            sizeTile(size, rank: index, saved: inProgress.first { !PuzzleRef.isDaily(id: $0.puzzleId) && $0.size == size })
                        }
                    }
                }
            }
            .padding(16)
        }
        .tint(TwoToneColors.accent)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let saved = resumeChoice {
                resumeDialog(saved)
            }
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .game(let id):
                TwoToneGameView(gameId: id, onOpen: open, onHome: { route = nil }).id(id)
            case .stats:
                TwoToneStatsView(store: store)
            case .history:
                TwoToneHistoryView(store: store, onOpen: open)
            case .settings:
                SettingsHubView(initial: .twoTone)
            }
        }
        .task {
            if let id = DailyRouter.shared.take(.twoTone).flatMap(Int64.init) {
                open(id)
            }
            guard let fixture, !fixtureOpened else {
                return
            }
            fixtureOpened = true
            open(await store.start { fixture })
        }
    }

    private func open(_ id: Int64) {
        route = .game(id)
    }

    private func launch(_ work: @escaping @MainActor () async -> Int64) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            open(await work())
            starting = false
        }
    }

    private func startNew(size: Int) {
        let seed = Int64.random(in: .min ... .max)
        launch { await store.start { PuzzleRef.random(seed: seed, size: size) } }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Two Tone").font(.largeTitle.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            DailyCalendarButton(tab: .twoTone)
            headerButton("chart.bar", "Stats", "stats") { route = .stats }
            headerButton("clock.arrow.circlepath", "History", "history") { route = .history }
            headerButton("gearshape", "Settings", "settings") { route = .settings }
        }
    }

    private func headerButton(_ icon: String, _ label: String, _ tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PuzzleIcon.image(icon).frame(width: 40, height: 40)
        }
        .tint(.primary)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            TwoToneGameIcon()
                .frame(width: 80, height: 80)
                .background(Color(uiColor: .systemBackground), in: .rect(cornerRadius: 20))
                .shadow(radius: 1)
            Text("Fill the grid red and blue, three simple rules")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [TwoToneColors.accent.opacity(0.2), TwoToneColors.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24)
        )
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(TwoToneColors.accent.opacity(0.25)) }
    }

    private func continueCard(_ game: TwoToneGameRecord) -> some View {
        Button {
            open(game.id)
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(TwoToneColors.accent)
                    .frame(width: 48, height: 48)
                    .overlay { PuzzleIcon.image("play.fill").foregroundStyle(.background) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue").font(.headline)
                    Text("\(game.title) · \(formatDuration(game.elapsedMs))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay { RoundedRectangle(cornerRadius: 24).stroke(TwoToneColors.accent, lineWidth: 2) }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private func section<Content: View>(_ title: String, aside: String?, @ViewBuilder content: () -> Content) -> some View {
        HomeSection(title, aside: aside, style: .headline(spacing: 12), content: content)
    }

    private func tileBackground(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(TwoToneColors.accent.opacity(highlighted ? 1 : 0.25), lineWidth: highlighted ? 2 : 1)
            }
    }

    private func dailyTile(_ size: Int, done: Bool, today: CalendarDay) -> some View {
        Button {
            launch { await store.openDaily(date: today, size: size) }
        } label: {
            VStack(spacing: 4) {
                Text(sizeLabel(size)).font(.subheadline.weight(.semibold)).lineLimit(1)
                if done {
                    PuzzleIcon.image("checkmark.circle.fill").foregroundStyle(TwoToneColors.accent)
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(tileBackground(highlighted: done))
            .background(done ? TwoToneColors.accent.opacity(0.16) : .clear, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily_\(size)")
    }

    private func sizeTile(_ size: Int, rank: Int, saved: TwoToneGameRecord?) -> some View {
        Button {
            if let saved {
                resumeChoice = saved
            } else {
                startNew(size: size)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(sizeLabel(size)).font(.headline)
                HStack(spacing: 3) {
                    ForEach(sizes.indices, id: \.self) { step in
                        Capsule()
                            .fill(TwoToneColors.accent.opacity(step <= rank ? 1 : 0.2))
                            .frame(height: 4)
                    }
                }
                if let saved {
                    HStack(spacing: 6) {
                        Circle().fill(TwoToneColors.accent).frame(width: 6, height: 6)
                        Text("In progress · \(formatDuration(saved.elapsedMs))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(tileBackground(highlighted: saved != nil))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("size_\(size)")
    }

    private func resumeDialog(_ saved: TwoToneGameRecord) -> some View {
        TwoToneDialog(title: saved.title, tag: "resume_dialog", onDismiss: { resumeChoice = nil }) {
            Text("You have a puzzle in progress (\(formatDuration(saved.elapsedMs))).")
        } buttons: {
            Button("New puzzle") {
                resumeChoice = nil
                startNew(size: saved.size)
            }
            .accessibilityIdentifier("new_game")
            Button("Resume") {
                resumeChoice = nil
                open(saved.id)
            }
            .accessibilityIdentifier("resume_game")
        }
    }
}

struct TwoToneGameIcon: View {
    var body: some View {
        SwiftUI.Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                square(TwoToneColors.red)
                square(TwoToneColors.blue)
            }
            GridRow {
                square(TwoToneColors.blue)
                square(TwoToneColors.red)
            }
        }
        .accessibilityHidden(true)
    }

    private func square(_ colour: Color) -> some View {
        RoundedRectangle(cornerRadius: 5).fill(colour).frame(width: 26, height: 26)
    }
}
