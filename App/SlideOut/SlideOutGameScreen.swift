import PuzzlesCore
import SwiftUI

struct SlideOutGameScreen: View {
    let gameId: Int64
    let onOpenGame: (Int64) -> Void
    let onHome: () -> Void

    var body: some View {
        SlideOutGameContent(model: SlideOutGameModel(gameId: gameId), onOpenGame: onOpenGame, onHome: onHome)
            .id(gameId)
    }
}

private struct SlideOutTourTargets: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    fileprivate func tourTarget(_ key: String) -> some View {
        anchorPreference(key: SlideOutTourTargets.self, value: .bounds) { [key: $0] }
    }
}

private let slideOutRules = [
    "Slide the red block out through the gap on the right.",
    "Blocks only slide along their length: across ones left and right, upright ones up and down.",
    "Each slide of a block is one move, however far it goes. Par is the fewest moves possible.",
]

private let slideOutTour = [
    ("board", "Drag a block along its length to slide it. Free the red block through the gap on the right."),
    ("hint", "Stuck? The bulb shows you the next step."),
    ("menu", "Restart, show the solution and settings live in this menu."),
]

private struct SlideOutGameContent: View {
    @State var model: SlideOutGameModel
    let onOpenGame: (Int64) -> Void
    let onHome: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SlideOutSettingKey.showTimer) private var showTimer = true
    @AppStorage(SlideOutSettingKey.showPar) private var showPar = true
    @AppStorage(SlideOutSettingKey.showHints) private var showHints = true
    @AppStorage(SlideOutSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SlideOutSettingKey.allowReveal) private var allowReveal = true
    @State private var showSettings = false
    @State private var revealing = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?
    @State private var failed = false

    private var colors: SlideColors { SlideColors.of(scheme) }

    var body: some View {
        VStack(spacing: 24) {
            header
            if let game = model.game {
                SlideOutBoardView(board: game.board, hint: game.hint) { block, position in
                    model.slide(block: block, to: position)
                }
                .tourTarget("board")
                .padding(.horizontal, 16)
            }
            Spacer()
        }
        .slideOutScreen()
        .overlayPreferenceValue(SlideOutTourTargets.self) { targets in
            GeometryReader { proxy in
                if let tourStep, let rect = targets[slideOutTour[tourStep].0].map({ proxy[$0] }) {
                    tourOverlay(step: tourStep, rect: rect)
                } else if let tourStep {
                    tourOverlay(step: tourStep, rect: nil)
                }
            }
        }
        .overlay { dialogs }
        .navigationDestination(isPresented: $showSettings) {
            SlideOutSettingsScreen { showSettings = false }
        }
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
        HStack(spacing: 0) {
            SlideOutBackButton(action: onHome)
            VStack(alignment: .leading) {
                Text(model.ref?.title ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if showTimer {
                        Text(SlideOutFormatDuration(model.elapsedMs)).monospacedDigit().accessibilityIdentifier("timer")
                    }
                    Text("Moves \(model.moveCount)").accessibilityIdentifier("move_count")
                    if showPar {
                        Text("Par \(model.par)").accessibilityIdentifier("par")
                    }
                }
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            SlideOutIconButton(
                systemName: "arrow.uturn.backward",
                label: "Undo the last move",
                id: "undo",
                enabled: model.canUndo
            ) { model.undo() }
            if showHints {
                SlideOutIconButton(systemName: "lightbulb", label: "Show a hint", id: "hint", enabled: !model.isSolved) {
                    Task { await model.hint() }
                }
                .tourTarget("hint")
            }
            if showTutorial {
                SlideOutIconButton(systemName: "questionmark.circle", label: "Show the rules", id: "rules") {
                    rulesOpen = true
                }
            }
            menu.tourTarget("menu")
        }
        .padding(.horizontal, 4)
    }

    private var menu: some View {
        Menu {
            Button("Restart this puzzle") { model.restart() }
                .disabled(model.isSolved)
                .accessibilityIdentifier("restart")
            Button("New puzzle", action: newPuzzle)
                .accessibilityIdentifier("new_puzzle")
            if allowReveal && !model.isSolved {
                Button("Show solution") { revealing = true }
                    .accessibilityIdentifier("menu_solution")
            }
            Button("Settings") { showSettings = true }
                .accessibilityIdentifier("menu_settings")
        } label: {
            Image(systemName: "ellipsis").frame(width: 40, height: 44)
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }

    @ViewBuilder
    private var dialogs: some View {
        if revealing {
            SlideOutDialog(id: "reveal_dialog", onDismiss: { revealing = false }) {
                Text("Show the solution?").font(.title2)
                Text("This ends the puzzle. It won't count towards best times.")
            } buttons: {
                Button("Cancel") { revealing = false }
                Button("Show solution") {
                    revealing = false
                    Task { await model.revealSolution() }
                }
                .accessibilityIdentifier("confirm_reveal")
            }
        } else if rulesOpen {
            SlideOutDialog(id: "rules_dialog", onDismiss: { rulesOpen = false }) {
                Text("How to play").font(.title2)
                ForEach(slideOutRules, id: \.self) { Text($0) }
            } buttons: {
                Button("Walk me through it") {
                    rulesOpen = false
                    tourStep = 0
                }
                .accessibilityIdentifier("walkthrough_start")
                Button("Got it") { rulesOpen = false }
                    .accessibilityIdentifier("rules_close")
            }
        } else if failed {
            SlideOutDialog(id: "load_failed_dialog", onDismiss: { failed = false }) {
                Text("Couldn't load that puzzle.")
            } buttons: {
                Button("OK") { failed = false }
            }
        } else if model.showSolvedDialog {
            solvedDialog
        }
    }

    private var solvedDialog: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.title)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(width: 64, height: 64)
                    .background(colors.accent, in: Circle())
                Text("Solved!").font(.title2).bold()
                if model.newBest {
                    Text("NEW BEST")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(colors.accent, in: Capsule())
                        .accessibilityIdentifier("new_best")
                }
                HStack(spacing: 8) {
                    stat("Moves", SlideOutSolvedMovesText(moveCount: model.moveCount, par: model.par), id: "solved_moves")
                    stat("Time", SlideOutFormatDuration(model.elapsedMs), id: "solved_time")
                    if model.hints > 0 {
                        stat("Hints", "\(model.hints)", id: "solved_hints")
                    }
                }
                stillToPlay
                HStack(spacing: 16) {
                    Spacer()
                    Button("Home", action: onHome).accessibilityIdentifier("solved_home")
                    Button("New puzzle", action: newPuzzle).accessibilityIdentifier("solved_new_puzzle")
                }
            }
            .padding(20)
            .background(
                LinearGradient(colors: [colors.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            )
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("solved_dialog")
        }
    }

    @ViewBuilder
    private var stillToPlay: some View {
        let today = CalendarDay.slideOutToday
        let left = SlideOutStore.dailiesLeft(today: today)
        if !left.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("STILL TO PLAY TODAY").font(.caption2).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(left, id: \.self) { level in
                            Button(level.label) { openDaily(level, today: today) }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(colors.accent.opacity(0.15), in: Capsule())
                                .accessibilityIdentifier("still_to_play_\(level.name.lowercased())")
                        }
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, id: String) -> some View {
        VStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(id)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func tourOverlay(step: Int, rect: CGRect?) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4).ignoresSafeArea()
            if let rect {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 4)
                    .frame(width: rect.width + 8, height: rect.height + 8)
                    .position(x: rect.midX, y: rect.midY)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(step + 1) of \(slideOutTour.count)").font(.caption2)
                Text(slideOutTour[step].1).accessibilityIdentifier("walkthrough_text")
                HStack(spacing: 16) {
                    Spacer()
                    Button(step == slideOutTour.count - 1 ? "Close" : "Skip") { tourStep = nil }
                        .accessibilityIdentifier("walkthrough_close")
                    if step > 0 {
                        Button("Back") { tourStep = step - 1 }
                            .accessibilityIdentifier("walkthrough_back")
                    }
                    if step < slideOutTour.count - 1 {
                        Button("Next") { tourStep = step + 1 }
                            .accessibilityIdentifier("walkthrough_next")
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walkthrough")
        }
    }

    private func newPuzzle() {
        Task {
            do {
                onOpenGame(try await model.newPuzzle())
            } catch {
                failed = true
            }
        }
    }

    private func openDaily(_ level: SlideOutLevel, today: CalendarDay) {
        Task {
            do {
                onOpenGame(SlideOutStore.start(try await SlideOutBank.shared.daily(level, date: today)))
            } catch {
                failed = true
            }
        }
    }
}
