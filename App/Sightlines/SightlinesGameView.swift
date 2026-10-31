import PuzzlesCore
import SightlinesEngine
import SwiftUI

private struct TourBounds: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    fileprivate func tourTarget(_ key: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: TourBounds.self, value: [key: proxy.frame(in: .named("sightlines_game"))])
            }
        }
    }
}

struct SightlinesGameView: View {
    let onOpenGame: (Int64) -> Void
    let onHome: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SightlinesSettings.inputMode) private var inputMode = SightlinesSettings.tapToCycle
    @AppStorage(SightlinesSettings.markBrokenRules) private var markBrokenRules = true
    @AppStorage(SightlinesSettings.showTimer) private var showTimer = true
    @AppStorage(SightlinesSettings.showProgress) private var showProgress = true
    @AppStorage(SightlinesSettings.showSeenCount) private var showSeenCount = true
    @AppStorage(SightlinesSettings.showHints) private var showHints = true
    @AppStorage(SightlinesSettings.showTutorial) private var showTutorial = true
    @AppStorage(SightlinesSettings.allowReveal) private var allowReveal = true
    @State private var model: SightlinesGameModel
    @State private var revealing = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?
    @State private var settingsOpen = false
    @State private var bounds: [String: CGRect] = [:]

    init(id: Int64, onOpenGame: @escaping (Int64) -> Void, onHome: @escaping () -> Void) {
        self.onOpenGame = onOpenGame
        self.onHome = onHome
        _model = State(initialValue: SightlinesGameModel(id: id, store: .shared))
    }

    private var pickColour: Bool {
        inputMode == SightlinesSettings.pickColour
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                if let game = model.game {
                    SightlinesBoardView(state: game, markBroken: markBrokenRules, showSeen: showSeenCount) {
                        model.onDot($0, pickColour: pickColour)
                    }
                    .tourTarget("board")
                    .padding(.horizontal, 12)
                    .padding(.top, 24)
                    if pickColour {
                        SightlinesColourPicker(colour: model.colour) { model.colour = $0 }.padding(.top, 16)
                    }
                    if let message = game.hint?.message {
                        Text(message).padding(.horizontal, 24).padding(.top, 16).accessibilityIdentifier("hint_message")
                    }
                }
                Spacer(minLength: 0)
            }
            if revealing {
                revealDialog
            }
            if model.solved && model.resultSaved {
                solvedDialog
            }
            if rulesOpen {
                rulesDialog
            }
            if let tourStep {
                walkthrough(tourStep)
            }
        }
        .coordinateSpace(name: "sightlines_game")
        .onPreferenceChange(TourBounds.self) { value in
            MainActor.assumeIsolated { bounds = value }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $settingsOpen) { SightlinesSettingsView() }
        .onAppear { model.onVisible() }
        .onDisappear { model.onHidden() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.onVisible()
            } else {
                model.onHidden()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading) {
                Text(model.title).font(.headline).lineLimit(1).minimumScaleFactor(0.7).accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if showTimer {
                        Text(formatDuration(ms: model.elapsedMs)).monospacedDigit().accessibilityIdentifier("timer")
                    }
                    if showProgress {
                        Text("\(model.game?.progressPercent ?? 0)%").accessibilityIdentifier("progress")
                    }
                }
            }
            Spacer(minLength: 0)
            tool("arrow.uturn.backward", "Undo the last tap", tag: "undo", enabled: model.canUndo) { model.onUndo() }
            tool("paintpalette", pickColour ? "Switch to tap to cycle" : "Switch to pick a colour", tag: "input_mode") {
                inputMode = pickColour ? SightlinesSettings.tapToCycle : SightlinesSettings.pickColour
            }
            if showHints {
                tool("lightbulb", "Show a hint", tag: "hint", enabled: !model.solved) { model.onHint() }.tourTarget("hint")
            }
            if showTutorial {
                tool("questionmark.circle", "Show the rules", tag: "rules") { rulesOpen = true }
            }
            menu.tourTarget("menu")
        }
        .padding(.horizontal, 12)
    }

    private func tool(
        _ icon: String,
        _ description: String,
        tag: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 40, height: 40)
        }
        .disabled(!enabled)
        .accessibilityLabel(description)
        .accessibilityIdentifier(tag)
    }

    private var menu: some View {
        Menu {
            Button("Restart this puzzle") { model.onRestart() }.disabled(model.solved).accessibilityIdentifier("restart")
            Button("New puzzle", action: newPuzzle).accessibilityIdentifier("new_puzzle")
            if allowReveal && !model.solved {
                Button("Show solution") { revealing = true }.accessibilityIdentifier("menu_solution")
            }
            Button("Settings") { settingsOpen = true }.accessibilityIdentifier("menu_settings")
        } label: {
            Image(systemName: "ellipsis").frame(width: 40, height: 40)
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }

    private var revealDialog: some View {
        SightlinesDialog(tag: "reveal_dialog", dismiss: { revealing = false }) {
            Text("Show the solution?").font(.title3.weight(.semibold))
            Text("This ends the puzzle. It won't count towards best times.")
            HStack(spacing: 16) {
                Spacer()
                Text("Cancel").sightlinesDialogAction("cancel_reveal") { revealing = false }
                Text("Show solution")
                    .sightlinesDialogAction("confirm_reveal") {
                        revealing = false
                        model.onReveal()
                    }
            }
        }
    }

    private var solvedDialog: some View {
        SightlinesDialog(tag: "solved_dialog") {
            VStack(spacing: 8) {
                Circle()
                    .fill(SightlinesColors.accent)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "trophy.fill").font(.title).foregroundStyle(Color(uiColor: .systemBackground))
                    }
                Text("Solved!").font(.title2.bold())
                if model.newBest {
                    Text("NEW BEST")
                        .font(.caption.bold())
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(SightlinesColors.accent, in: Capsule())
                        .accessibilityIdentifier("new_best")
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                stat("Time", formatDuration(ms: model.elapsedMs), tag: "solved_time")
                if model.hints > 0 {
                    stat("Hints", "\(model.hints)", tag: nil)
                }
            }
            dailiesLeft
            HStack(spacing: 16) {
                Spacer()
                Text("Home").sightlinesDialogAction("solved_home", action: onHome)
                Text("New puzzle").sightlinesDialogAction("solved_new_puzzle", action: newPuzzle)
            }
        }
    }

    @ViewBuilder
    private var dailiesLeft: some View {
        let date = SightlinesToday.date
        let solved = SightlinesStore.shared.games.dailySolved(date: date)
        let left = sizes.filter { !solved.contains($0) }
        if !left.isEmpty {
            Text("STILL TO PLAY TODAY").font(.caption2).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(left, id: \.self) { size in
                        Button {
                            openDaily(date: date, size: size)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Sightlines \(sizeLabel(size))").font(.caption.weight(.medium))
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(SightlinesColors.accent)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(SightlinesColors.accent.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("daily_left_\(size)")
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, tag: String?) -> some View {
        VStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            statValue(value, tag: tag)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(SightlinesColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statValue(_ value: String, tag: String?) -> some View {
        if let tag {
            Text(value).font(.headline).accessibilityIdentifier(tag)
        } else {
            Text(value).font(.headline)
        }
    }

    private static let rules = [
        "Fill every dot blue or red. Tap a dot to cycle it: blue, red, empty.",
        "Blue dots can see other blue dots in their own row and column. Red dots block the view.",
        "A number says how many blue dots that dot can see.",
        "Every blue dot must see at least one other.",
    ]

    private static let tutorial = [
        ("board", "Tap a dot to cycle it blue, red, empty. A number says how many blue dots it can see; red dots block the view."),
        ("hint", "Stuck? The bulb shows you the next step."),
        ("menu", "Restart, show the solution and settings live in this menu."),
    ]

    private var rulesDialog: some View {
        SightlinesDialog(tag: "rules_dialog", dismiss: { rulesOpen = false }) {
            Text("How to play").font(.title3.weight(.semibold))
            ForEach(Self.rules, id: \.self) { Text($0) }
            HStack(spacing: 16) {
                Spacer()
                Text("Walk me through it")
                    .sightlinesDialogAction("walkthrough_start") {
                        rulesOpen = false
                        tourStep = 0
                    }
                Text("Got it").sightlinesDialogAction("rules_close") { rulesOpen = false }
            }
        }
    }

    private func walkthrough(_ index: Int) -> some View {
        let step = Self.tutorial[index]
        let last = index == Self.tutorial.count - 1
        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
            if let target = bounds[step.0] {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SightlinesColors.accent, lineWidth: 4)
                    .frame(width: target.width + 8, height: target.height + 8)
                    .position(x: target.midX, y: target.midY)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(index + 1) of \(Self.tutorial.count)").font(.caption2)
                Text(step.1).accessibilityIdentifier("walkthrough_text")
                HStack(spacing: 16) {
                    Spacer()
                    Text(last ? "Close" : "Skip").sightlinesDialogAction("walkthrough_close") { tourStep = nil }
                    if index > 0 {
                        Text("Back").sightlinesDialogAction("walkthrough_back") { tourStep = index - 1 }
                    }
                    if !last {
                        Text("Next").sightlinesDialogAction("walkthrough_next") { tourStep = index + 1 }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walkthrough")
            .padding(16)
        }
    }

    private func newPuzzle() {
        guard let size = model.size else {
            return
        }
        model.closeForNewPuzzle()
        let seed = Int64.random(in: .min ... .max)
        Task {
            onOpenGame(await SightlinesStore.shared.start { PuzzleRef.random(seed: seed, size: size) })
        }
    }

    private func openDaily(date: CalendarDay, size: Int) {
        let store = SightlinesStore.shared
        if let existing = store.games.dailyInProgress(date: date, size: size) {
            onOpenGame(existing.id)
            return
        }
        Task {
            onOpenGame(await store.start { PuzzleRef.daily(date: date, size: size) })
        }
    }
}
