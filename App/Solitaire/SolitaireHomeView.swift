import PuzzlesCore
import SolitaireEngine
import SwiftUI

private enum SolitaireRoute: Hashable {
    case stats
    case history
    case settings
    case game(Int64)
}

private enum DealKind {
    case new
    case daily
}

struct SolitaireHomeView: View {
    private let startDeal: DealRef?

    @State private var store = SolitaireStore.shared
    @State private var route: SolitaireRoute?
    @State private var dealing: DealKind?
    @State private var resumeChoice: SavedGame?
    @State private var startedFixture = false
    @Environment(\.dismiss) private var dismiss

    init(startDeal: DealRef? = nil) {
        self.startDeal = startDeal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                hero
                if let latest = store.inProgress.first {
                    continueCard(latest)
                }
                section("Today", aside: DealRef.dayLabel(iso: CalendarDay.today.isoString)) {
                    dailyTile
                }
                section("New game", aside: nil) {
                    newGameTile
                }
            }
            .padding(16)
        }
        .solitaireScreen()
        .overlay { resumeDialog }
        .navigationDestination(item: $route) { destination($0) }
        .task {
            if let id = DailyRouter.shared.take(.solitaire).flatMap(Int64.init) {
                route = .game(id)
            }
            if let startDeal, !startedFixture {
                startedFixture = true
                route = .game(store.start(startDeal).id)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: SolitaireRoute) -> some View {
        switch route {
        case .stats:
            SolitaireStatsView(store: store) { self.route = nil }
        case .history:
            SolitaireHistoryView(store: store, onOpenGame: { self.route = .game($0) }) { self.route = nil }
        case .settings:
            SettingsHubView(initial: .solitaire) { self.route = nil }
        case .game(let id):
            SolitaireGameView(id: id, onOpenGame: { self.route = .game($0) }) { self.route = nil }
                .id(id)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            SolitaireBackButton { dismiss() }
            Text("Solitaire")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            DailyCalendarButton(tab: .solitaire)
            SolitaireIconButton(symbol: "chart.bar", label: "Stats", tag: "stats") { route = .stats }
            SolitaireIconButton(symbol: "clock.arrow.circlepath", label: "History", tag: "history") { route = .history }
            SolitaireIconButton(symbol: "gearshape", label: "Settings", tag: "settings") { route = .settings }
        }
    }

    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        return HStack(spacing: 16) {
            SolitaireGameIcon()
                .frame(width: 80, height: 80)
                .background(SolitaireColors.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 1)
                .accessibilityHidden(true)
            Text("Klondike, draw 1 or 3, or reverse")
                .foregroundStyle(SolitaireColors.onSurfaceVariant)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [SolitaireColors.accent.opacity(0.2), SolitaireColors.accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: shape
        )
        .overlay(shape.stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
    }

    private func continueCard(_ game: SavedGame) -> some View {
        Button {
            route = .game(game.id)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(SolitaireColors.accent).frame(width: 48, height: 48)
                    PuzzleIcon.image("play.fill").foregroundStyle(SolitaireColors.background)
                }
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text(game.continueDetail)
                        .font(.subheadline)
                        .foregroundStyle(SolitaireColors.onSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.right").foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
            .padding(16)
            .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(SolitaireColors.accent, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue")
    }

    private func section<Content: View>(_ title: String, aside: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let aside {
                    Text(aside).font(.subheadline).foregroundStyle(SolitaireColors.onSurfaceVariant)
                }
            }
            content()
        }
    }

    private var dailyTile: some View {
        let won = store.dailyWon(DealRef.dailyId(CalendarDay.today))
        return tile(
            label: dealing == .daily ? "Dealing…" : "Daily deal",
            detail: won ? "Won" : nil,
            symbol: "calendar",
            highlighted: won,
            done: won,
            tag: "daily",
            action: openDaily
        )
    }

    private var newGameTile: some View {
        let saved = store.savedDeal
        return tile(
            label: dealing == .new ? "Dealing…" : "New game",
            detail: saved.map { "In progress · \(formatDuration($0.elapsedMs))" },
            symbol: "suit.spade",
            highlighted: saved != nil,
            done: false,
            tag: "play"
        ) {
            if let saved {
                resumeChoice = saved
            } else {
                startNew()
            }
        }
    }

    private func tile(
        label: String,
        detail: String?,
        symbol: String,
        highlighted: Bool,
        done: Bool,
        tag: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PuzzleIcon.image(symbol)
                    .foregroundStyle(SolitaireColors.accent)
                    .frame(width: 40, height: 40)
                    .background(SolitaireColors.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.headline)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
                    }
                }
                Spacer(minLength: 0)
                PuzzleIcon.image(done ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(done ? SolitaireColors.accent : SolitaireColors.onSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(SolitaireColors.accent.opacity(highlighted ? 1 : 0.25), lineWidth: highlighted ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(dealing != nil)
        .accessibilityIdentifier(tag)
    }

    @ViewBuilder
    private var resumeDialog: some View {
        if let saved = resumeChoice {
            SolitaireDialog(tag: "resume_dialog", onDismiss: { resumeChoice = nil }) {
                Text(saved.deal.title).font(.title3.weight(.semibold))
                Text("You have a game in progress (\(formatDuration(saved.elapsedMs))).")
                HStack {
                    Spacer()
                    SolitaireTextButton(title: "New deal", tag: "new_game") {
                        resumeChoice = nil
                        startNew()
                    }
                    SolitaireTextButton(title: "Resume", tag: "resume_game") {
                        resumeChoice = nil
                        route = .game(saved.id)
                    }
                }
            }
        }
    }

    private func startNew() {
        dealing = .new
        Task {
            let prefs = SolitairePreferences.current
            let seeds = await SolitaireDealer.winnableSeeds(drawMode: prefs.drawMode, order: prefs.order, enabled: prefs.winnableOnly)
            let deal = DealRef.random(seed: SolitaireDealer.newSeed(), drawMode: prefs.drawMode, order: prefs.order, winnableSeeds: seeds)
            route = .game(store.start(deal).id)
            dealing = nil
        }
    }

    private func openDaily() {
        let day = CalendarDay.today
        if let existing = store.inProgress.first(where: { $0.deal.id == DealRef.dailyId(day) }) {
            route = .game(existing.id)
            return
        }
        dealing = .daily
        Task {
            let prefs = SolitairePreferences.current
            let seeds = await SolitaireDealer.winnableSeeds(drawMode: prefs.drawMode, order: prefs.order, enabled: prefs.winnableOnly)
            let deal = DealRef.daily(day: day, drawMode: prefs.drawMode, order: prefs.order, winnableSeeds: seeds)
            route = .game(store.start(deal).id)
            dealing = nil
        }
    }
}
