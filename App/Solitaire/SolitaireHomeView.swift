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

struct SolitaireStatsView: View {
    let store: SolitaireStore
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    SolitaireBackButton(action: onBack)
                    Text("Stats").font(.largeTitle)
                }
                ForEach(store.stats(), id: \.drawMode) { mode in
                    panel(mode)
                }
                Text("Abandoned deals count as played. Daily deals count under the draw mode they were played with.")
                    .font(.caption)
                    .foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
            .padding(16)
        }
        .solitaireScreen()
    }

    private func panel(_ mode: DrawStats) -> some View {
        let tag = mode.drawMode.tagName
        return VStack(alignment: .leading, spacing: 8) {
            Text(mode.drawMode.label).font(.title2)
            row("Played", "\(mode.played)", tag: "\(tag)_played")
            row("Won", "\(mode.won)", tag: "\(tag)_won")
            row("Win rate", mode.winRate, tag: "\(tag)_win_rate")
            row("Best time", mode.bestMs.map(formatDuration) ?? "–", tag: "\(tag)_best")
            row("Average time", mode.averageMs.map(formatDuration) ?? "–", tag: "\(tag)_average")
            row("Fewest moves", mode.fewestMoves.map(String.init) ?? "–", tag: "\(tag)_fewest_moves")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
    }

    private func row(_ label: String, _ value: String, tag: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).accessibilityIdentifier(tag)
        }
    }
}

struct SolitaireHistoryView: View {
    let store: SolitaireStore
    let onOpenGame: (Int64) -> Void
    let onBack: () -> Void
    @State private var filter: DrawMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                SolitaireBackButton(action: onBack)
                Text("History").font(.largeTitle)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", selected: filter == nil, tag: "filter_all") { filter = nil }
                    ForEach(DrawMode.allCases, id: \.self) { mode in
                        chip(mode.label, selected: filter == mode, tag: "filter_\(mode.tagName)") { filter = mode }
                    }
                }
                .padding(1)
            }
            let games = store.history(filter: filter)
            if games.isEmpty {
                Text("No games yet.")
                    .foregroundStyle(SolitaireColors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, minHeight: 120)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(games) { game in
                            item(game)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(SolitaireColors.accent.opacity(0.25), lineWidth: 1))
            }
        }
        .padding(16)
        .solitaireScreen()
    }

    private func chip(_ label: String, selected: Bool, tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? SolitaireColors.accent.opacity(0.2) : .clear, in: Capsule())
                .overlay(Capsule().stroke(SolitaireColors.accent.opacity(selected ? 1 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag)
    }

    private func item(_ game: SavedGame) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(game.deal.title).font(.subheadline.weight(.medium))
                Text(Self.date(game.startedAt)).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatDuration(game.elapsedMs))
                Text(game.summary).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if game.status == .inProgress {
                onOpenGame(game.id)
            } else {
                onOpenGame(store.start(game.deal).id)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history_item")
    }

    private static func date(_ ms: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}

struct SolitaireSettingsView: View {
    let onBack: () -> Void
    @AppStorage(SolitaireSettingKey.drawMode) private var drawMode = DrawMode.drawOne.storageName
    @AppStorage(SolitaireSettingKey.reverse) private var reverse = false
    @AppStorage(SolitaireSettingKey.oneTapMove) private var oneTapMove = true
    @AppStorage(SolitaireSettingKey.winnableOnly) private var winnableOnly = true
    @AppStorage(SolitaireSettingKey.warnUnwinnable) private var warnUnwinnable = false
    @AppStorage(SolitaireSettingKey.showTimer) private var showTimer = true
    @AppStorage(SolitaireSettingKey.showMoveCount) private var showMoveCount = true
    @AppStorage(SolitaireSettingKey.showHints) private var showHints = false
    @AppStorage(SolitaireSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SolitaireSettingKey.hintFill) private var hintFill = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Play").font(.title2)
                    drawChoice
                    Text("Draw 3 is harder. Applies to new games.").font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
                    row(
                        "Reverse",
                        "Foundations start with kings, columns build up from aces. Applies to new games.",
                        $reverse,
                        tag: "setting_reverse"
                    )
                    row(
                        "One tap to move",
                        "Tapping a card sends it to the best place. Off: tap a card, then where it should go.",
                        $oneTapMove,
                        tag: "setting_one_tap_move"
                    )
                    row(
                        "Winnable deals only", "Every new deal can be won. Applies to new deals.", $winnableOnly,
                        tag: "setting_winnable_only")
                    row(
                        "Tell me when a deal can't be won",
                        "Checks after a full pass through the stock with no move, and offers to undo to the last winnable position.",
                        $warnUnwinnable,
                        tag: "setting_warn_unwinnable"
                    )
                    row("Show the timer", nil, $showTimer, tag: "setting_show_timer")
                    row("Show the move counter", nil, $showMoveCount, tag: "setting_show_move_count")
                    row("Hints", "Show the hint button.", $showHints, tag: "setting_show_hints")
                    row("How to play", "Show the ? button with the rules and a walkthrough.", $showTutorial, tag: "setting_show_tutorial")
                    if showHints {
                        row(
                            "Hints fill the answer in", "Off: a hint points at the next step and says why.", $hintFill,
                            tag: "setting_hint_fill")
                    }
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SolitaireColors.onSurfaceVariant.opacity(0.4), lineWidth: 1))
            }
            .padding(16)
        }
        .solitaireScreen()
    }

    private var drawChoice: some View {
        HStack(spacing: 0) {
            ForEach(DrawMode.allCases, id: \.self) { mode in
                Button {
                    drawMode = mode.storageName
                } label: {
                    Text(mode.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(drawMode == mode.storageName ? SolitaireColors.accent.opacity(0.2) : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setting_\(mode.tagName)")
                .accessibilityAddTraits(drawMode == mode.storageName ? .isSelected : [])
            }
        }
        .overlay(Capsule().stroke(SolitaireColors.onSurfaceVariant.opacity(0.5), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func row(_ title: String, _ detail: String?, _ value: Binding<Bool>, tag: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(SolitaireColors.accent)
                .accessibilityIdentifier(tag)
        }
    }
}
