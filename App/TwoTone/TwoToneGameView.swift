import PuzzlesCore
import SwiftUI
import TwoToneEngine

private struct TourAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct TourStep {
    let target: String
    let text: String
}

private let rules = [
    "Fill every tile red or blue. Tap a tile to cycle it: red, blue, empty.",
    "No three tiles of the same colour next to each other in a row or column.",
    "Every row and column has as many red tiles as blue.",
    "No two rows are the same, and no two columns are the same.",
]

private let tutorial = [
    TourStep(
        target: "board",
        text: "Tap a tile to cycle it red, blue, empty. No three of a colour in a line, and each row and column is half red, half blue."
    ),
    TourStep(target: "hint", text: "Stuck? The bulb shows you the next step."),
    TourStep(target: "menu", text: "Restart, show the solution and settings live in this menu."),
]

struct TwoToneGameView: View {
    let gameId: Int64
    let onOpen: (Int64) -> Void
    let onHome: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var store = TwoToneStore.shared
    @State private var model: TwoToneGameModel?
    @State private var showGivens = false
    @State private var revealing = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?
    @State private var settingsOpen = false

    @AppStorage(TwoToneSettingKey.inputMode) private var inputMode = TwoToneInputMode.tapToCycle.rawValue
    @AppStorage(TwoToneSettingKey.markBrokenRules) private var markBrokenRules = true
    @AppStorage(TwoToneSettingKey.showTimer) private var showTimer = true
    @AppStorage(TwoToneSettingKey.showProgress) private var showProgress = true
    @AppStorage(TwoToneSettingKey.showHints) private var showHints = true
    @AppStorage(TwoToneSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(TwoToneSettingKey.allowReveal) private var allowReveal = true

    private var pickColour: Bool {
        inputMode == TwoToneInputMode.pickColour.rawValue
    }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .tint(TwoToneColors.accent)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $settingsOpen) {
            SettingsHubView(initial: .twoTone)
        }
        .task {
            if model == nil {
                model = TwoToneGameModel(id: gameId, store: store)
            }
            model?.onVisible()
        }
        .onAppear { model?.onVisible() }
        .onDisappear { model?.onHidden() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model?.onVisible()
            } else {
                model?.onHidden()
            }
        }
    }

    private func content(_ model: TwoToneGameModel) -> some View {
        VStack(spacing: 0) {
            topBar(model)
            TwoToneBoardView(
                grid: model.game.grid,
                marks: model.game.boardMarks(markBrokenRules: markBrokenRules),
                showGivens: showGivens,
                onTile: { model.onTile($0, pickColour: pickColour) }
            )
            .anchorPreference(key: TourAnchors.self, value: .bounds) { ["board": $0] }
            .padding(.horizontal, 12)
            .padding(.top, 24)
            if pickColour {
                TwoToneColourPicker(colour: Bindable(model).colour).padding(.top, 16)
            }
            if let message = model.game.hint?.message {
                Text(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .accessibilityIdentifier("hint_message")
            }
            Spacer(minLength: 0)
        }
        .overlayPreferenceValue(TourAnchors.self) { anchors in
            GeometryReader { proxy in
                if let tourStep {
                    TwoToneWalkthrough(
                        step: tutorial[tourStep],
                        index: tourStep,
                        count: tutorial.count,
                        target: anchors[tutorial[tourStep].target].map { proxy[$0] },
                        onStep: { self.tourStep = $0 },
                        onClose: { self.tourStep = nil }
                    )
                }
            }
        }
        .overlay { dialogs(model) }
    }

    private func topBar(_ model: TwoToneGameModel) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if showTimer {
                        Text(formatDuration(model.elapsedMs)).monospacedDigit().accessibilityIdentifier("timer")
                    }
                    if showProgress {
                        Text("\(model.game.progressPercent)%").accessibilityIdentifier("progress")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            HStack(spacing: 0) {
                tool("arrow.uturn.backward", "Undo the last tap", "undo", enabled: model.canUndo) { model.onUndo() }
                tool(showGivens ? "smallcircle.filled.circle.fill" : "smallcircle.filled.circle", showGivens ? "Hide the starting tiles" : "Show the starting tiles", "starting_tiles") {
                    showGivens.toggle()
                }
                tool("paintpalette", pickColour ? "Switch to tap to cycle" : "Switch to pick a colour", "input_mode") {
                    inputMode = (pickColour ? TwoToneInputMode.tapToCycle : .pickColour).rawValue
                }
                if showHints {
                    tool("lightbulb", "Show a hint", "hint", enabled: !model.game.isSolved) { model.onHint() }
                        .anchorPreference(key: TourAnchors.self, value: .bounds) { ["hint": $0] }
                }
                if showTutorial {
                    tool("questionmark.circle", "Show the rules", "rules") { rulesOpen = true }
                }
                menu(model)
                    .anchorPreference(key: TourAnchors.self, value: .bounds) { ["menu": $0] }
            }
            .padding(.horizontal, 4)
        }
    }

    private func tool(_ icon: String, _ label: String, _ tag: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PuzzleIcon.image(icon).frame(width: 38, height: 44)
        }
        .tint(.primary)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    private func menu(_ model: TwoToneGameModel) -> some View {
        Menu {
            Button("Restart this puzzle") { model.onRestart() }
                .disabled(model.game.isSolved)
                .accessibilityIdentifier("restart")
            Button("New puzzle") { newPuzzle(model) }
                .accessibilityIdentifier("new_puzzle")
            if allowReveal && !model.game.isSolved {
                Button("Show solution") { revealing = true }
                    .accessibilityIdentifier("menu_solution")
            }
            Button("Settings") { settingsOpen = true }
                .accessibilityIdentifier("menu_settings")
        } label: {
            PuzzleIcon.image("ellipsis").frame(width: 38, height: 44)
        }
        .tint(.primary)
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }

    private func newPuzzle(_ model: TwoToneGameModel) {
        let size = model.size
        let seed = Int64.random(in: .min ... .max)
        Task {
            onOpen(await store.start { PuzzleRef.random(seed: seed, size: size) })
        }
    }

    @ViewBuilder
    private func dialogs(_ model: TwoToneGameModel) -> some View {
        if revealing {
            TwoToneDialog(title: "Show the solution?", onDismiss: { revealing = false }) {
                Text("This ends the puzzle. It won't count towards best times.")
            } buttons: {
                Button("Cancel") { revealing = false }
                Button("Show solution") {
                    revealing = false
                    model.onReveal()
                }
                .accessibilityIdentifier("confirm_reveal")
            }
        }
        if rulesOpen {
            TwoToneDialog(title: "How to play", onDismiss: { rulesOpen = false }) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rules, id: \.self) { Text($0) }
                }
            } buttons: {
                Button("Walk me through it") {
                    rulesOpen = false
                    tourStep = 0
                }
                .accessibilityIdentifier("walkthrough_start")
                Button("Got it") { rulesOpen = false }
                    .accessibilityIdentifier("rules_close")
            }
        }
        if model.game.isSolved && model.resultSaved {
            TwoToneSolvedDialog(
                model: model,
                dailiesLeft: dailiesLeft(),
                onDaily: { size in
                    Task { onOpen(await store.openDaily(date: TwoToneStore.today(), size: size)) }
                },
                onNewPuzzle: { newPuzzle(model) },
                onHome: onHome
            )
        }
    }

    private func dailiesLeft() -> [Int] {
        let solved = store.dailySolved(date: TwoToneStore.today())
        return sizes.filter { !solved.contains($0) }
    }
}

private struct TwoToneWalkthrough: View {
    let step: TourStep
    let index: Int
    let count: Int
    let target: CGRect?
    let onStep: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
            if let target {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.primary, lineWidth: 4)
                    .frame(width: target.width + 12, height: target.height + 12)
                    .position(x: target.midX, y: target.midY)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(index + 1) of \(count)").font(.caption)
                Text(step.text).accessibilityIdentifier("walkthrough_text")
                HStack(spacing: 16) {
                    Spacer()
                    Button(index == count - 1 ? "Close" : "Skip", action: onClose)
                        .accessibilityIdentifier("walkthrough_close")
                    if index > 0 {
                        Button("Back") { onStep(index - 1) }.accessibilityIdentifier("walkthrough_back")
                    }
                    if index < count - 1 {
                        Button("Next") { onStep(index + 1) }.accessibilityIdentifier("walkthrough_next")
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .padding(16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walkthrough")
        }
    }
}

private struct TwoToneSolvedDialog: View {
    let model: TwoToneGameModel
    let dailiesLeft: [Int]
    let onDaily: (Int) -> Void
    let onNewPuzzle: () -> Void
    let onHome: () -> Void

    @State private var popped = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
            VStack(spacing: 12) {
                Circle()
                    .fill(TwoToneColors.accent)
                    .frame(width: 64, height: 64)
                    .overlay {
                        PuzzleIcon.image("trophy.fill").font(.title).foregroundStyle(.background)
                    }
                    .scaleEffect(popped ? 1 : 0.6)
                    .accessibilityHidden(true)
                Text("Solved!").font(.title2.bold())
                if model.newBest {
                    Text("NEW BEST")
                        .font(.caption.bold())
                        .foregroundStyle(.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(TwoToneColors.accent, in: .capsule)
                        .accessibilityIdentifier("new_best")
                }
                HStack(spacing: 8) {
                    stat("Time", formatDuration(model.elapsedMs), tag: "solved_time")
                    if model.hints > 0 {
                        stat("Hints", "\(model.hints)", tag: nil)
                    }
                }
                if !dailiesLeft.isEmpty {
                    Text("STILL TO PLAY TODAY")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dailiesLeft, id: \.self) { size in
                                Button("Two Tone \(sizeLabel(size))") { onDaily(size) }
                                    .font(.footnote)
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                HStack(spacing: 16) {
                    Spacer()
                    Button("Home", action: onHome).accessibilityIdentifier("solved_home")
                    Button("New puzzle", action: onNewPuzzle).accessibilityIdentifier("solved_new_puzzle")
                }
            }
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28).stroke(TwoToneColors.accent.opacity(0.3))
            }
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("solved_dialog")
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                popped = true
            }
        }
    }

    private func stat(_ label: String, _ value: String, tag: String?) -> some View {
        VStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline).accessibilityIdentifier(tag ?? "")
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(TwoToneColors.accent.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}
