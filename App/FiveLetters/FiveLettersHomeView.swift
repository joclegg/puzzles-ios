import FiveLettersEngine
import PuzzlesCore
import SwiftUI

struct FiveLettersGameRoute: Hashable, Identifiable {
    let id: String
}

struct FiveLettersHomeView: View {
    var fixture: WordRef?

    private let theme = FiveLettersTheme()
    private let store = FiveLettersStore.shared
    @State private var dailyNumber = Words.dayNumber(Self.today)
    @State private var starting = false
    @State private var nytUnavailable = false
    @State private var openGame: FiveLettersGameRoute?
    @State private var fixtureStarted = false

    private static var today: CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    private static var todayLabel: String {
        Date.now.formatted(Date.FormatStyle(locale: Locale(identifier: "en_GB")).day().month(.abbreviated))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                today
                practice
                Text("Everyone with Puzzles gets the same word each day, so you can compare grids.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .fiveLettersHeader("Five Letters")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                DailyCalendarButton(tab: .fiveLetters)
                NavigationLink {
                    FiveLettersStatsView()
                } label: {
                    Label {
                        Text("Stats")
                    } icon: {
                        PuzzleIcon.image("chart.bar")
                    }
                }
                .accessibilityIdentifier("stats")
                NavigationLink {
                    SettingsHubView(initial: .fiveLetters)
                } label: {
                    Label {
                        Text("Settings")
                    } icon: {
                        PuzzleIcon.image("gearshape")
                    }
                }
                .accessibilityIdentifier("settings")
            }
        }
        .navigationDestination(item: $openGame) { route in
            FiveLettersGameView(uuid: route.id)
        }
        .onAppear {
            dailyNumber = Words.dayNumber(Self.today)
            if let id = DailyRouter.shared.take(.fiveLetters) {
                openGame = FiveLettersGameRoute(id: id)
            }
            if let fixture, !fixtureStarted {
                fixtureStarted = true
                open(store.start(ref: fixture, hardMode: FiveLettersSetting.hardMode.current))
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            FiveLettersGameIcon()
                .frame(width: 80, height: 80)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
                .shadow(radius: 1)
            Text("Guess the word in six tries, a new one every day")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(theme.accent.opacity(0.25))
        }
    }

    private var today: some View {
        let date = Self.today
        let daily = store.existing(wordId: WordRef.dailyId(date))?.status
        let nyt = store.existing(wordId: WordRef.nytId(date))?.status
        return section("Today", aside: Self.todayLabel) {
            tile(
                "Today's word · #\(dailyNumber)",
                id: "daily",
                icon: "calendar",
                detail: daily?.homeLabel,
                active: daily == .inProgress,
                done: daily == .won
            ) {
                launch { try await openDaily(date) }
            }
            tile(
                "NY Times daily",
                id: "nyt_daily",
                icon: "newspaper",
                detail: nyt?.homeLabel,
                active: nyt == .inProgress,
                done: nyt == .won
            ) {
                launch { await openNyt(date) }
            }
            if nytUnavailable {
                Text("Couldn't reach the New York Times. Check your connection and try again.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("nyt_unavailable")
            }
        }
    }

    private var practice: some View {
        let current = store.practice
        return section("Practice", aside: nil) {
            HStack(spacing: 8) {
                tile(
                    current == nil ? "Practice" : "Continue practice",
                    id: "practice",
                    icon: "dumbbell",
                    detail: nil,
                    active: current != nil,
                    done: false
                ) {
                    if let current {
                        open(current)
                    } else {
                        launch { try await startPractice() }
                    }
                }
                if current != nil {
                    tile("New word", id: "new_practice", icon: "arrow.clockwise", detail: nil, active: false, done: false) {
                        launch { try await startPractice() }
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        aside: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
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

    private func tile(
        _ label: String,
        id: String,
        icon: String,
        detail: String?,
        active: Bool,
        done: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PuzzleIcon.image(icon)
                    .foregroundStyle(theme.accent)
                    .frame(width: 40, height: 40)
                    .background(theme.accent.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).fontWeight(.semibold)
                    if let detail {
                        HStack(spacing: 6) {
                            if active {
                                Circle().fill(theme.accent).frame(width: 6, height: 6)
                            }
                            Text(detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                if done {
                    PuzzleIcon.image("checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                } else {
                    PuzzleIcon.image("chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(active || done ? theme.accent.opacity(0.5) : Color.primary.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func open(_ game: SavedGame) {
        openGame = FiveLettersGameRoute(id: game.uuid)
    }

    private func launch(_ start: @escaping @MainActor () async throws -> Void) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            try? await start()
            starting = false
        }
    }

    private func openDaily(_ date: CalendarDay) async throws {
        if let existing = store.existing(wordId: WordRef.dailyId(date)) {
            open(existing)
            return
        }
        let words = try await store.words()
        open(store.start(ref: .daily(words: words, date: date), hardMode: FiveLettersSetting.hardMode.current))
    }

    private func openNyt(_ date: CalendarDay) async {
        if let existing = store.existing(wordId: WordRef.nytId(date)) {
            nytUnavailable = false
            open(existing)
            return
        }
        guard let answer = await FiveLettersNyt.word(date: date.isoString) else {
            nytUnavailable = true
            return
        }
        nytUnavailable = false
        open(store.start(ref: .nyt(date: date, answer: answer), hardMode: FiveLettersSetting.hardMode.current))
    }

    private func startPractice() async throws {
        let words = try await store.words()
        open(
            store.start(
                ref: .practice(words: words, seed: Int64.random(in: .min ... .max)),
                hardMode: FiveLettersSetting.hardMode.current
            )
        )
    }
}

struct FiveLettersGameIcon: View {
    private let theme = FiveLettersTheme()

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                square("W", theme.correct)
                square("O", theme.present)
            }
            HStack(spacing: 4) {
                square("R", theme.absent)
                square("D", theme.correct)
            }
        }
    }

    private func square(_ letter: String, _ colour: Color) -> some View {
        Text(letter)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(theme.markedText)
            .frame(width: 26, height: 26)
            .background(colour, in: .rect(cornerRadius: 4))
    }
}
