import SudokuEngine
import SwiftUI

@MainActor
@Observable
final class SudokuGameModel {
    private(set) var saved: SudokuSavedGame?
    private(set) var state: GameState?
    private(set) var elapsedMs: Int64 = 0
    private(set) var display = ModeSettings()
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var revealed = false
    private(set) var hintMessage: String?

    private var timer = GameTimer()
    private var visible = false
    private var ticker: Task<Void, Never>?
    private let store = SudokuStore.shared

    private static let tick = Duration.milliseconds(500)

    init(id: Int) {
        guard let loaded = store.game(id) else {
            return
        }
        saved = loaded
        state = GameState(
            puzzle: loaded.ref.puzzle,
            values: loaded.values,
            notes: loaded.notes,
            inputMode: sudokuInputMode(),
            mistakeCheck: loaded.mistakeCheck,
            mistakes: loaded.mistakes,
            undoStack: loaded.moves,
            options: sudokuModeSettings(loaded.ref.mode).playOptions
        )
        timer = GameTimer(accumulatedMs: loaded.elapsedMs)
        elapsedMs = loaded.elapsedMs
        revealed = loaded.status == .revealed
    }

    private static func nowMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    func onVisible() {
        visible = true
        applySettings()
        resumeTimer()
    }

    func onHidden() {
        visible = false
        timer = timer.pause(nowMs: Self.nowMs())
        ticker?.cancel()
        persist()
    }

    private func applySettings() {
        guard let saved, var current = state else {
            return
        }
        display = sudokuModeSettings(saved.ref.mode)
        current.options = display.playOptions
        let input = sudokuInputMode()
        state = current.inputMode == input ? current : current.withInputMode(input)
    }

    private func resumeTimer() {
        guard let state, !state.isComplete, !revealed else {
            return
        }
        timer = timer.start(nowMs: Self.nowMs())
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                self.elapsedMs = self.timer.elapsedMs(nowMs: Self.nowMs())
                try? await Task.sleep(for: Self.tick)
            }
        }
    }

    func move(_ change: (GameState) -> GameState) {
        guard let before = state else {
            return
        }
        let after = change(before)
        if after == before {
            return
        }
        state = after
        hintMessage = nil
        if !before.isComplete && after.isComplete {
            finish()
        } else if after.values != before.values || after.notes != before.notes || after.mistakes != before.mistakes {
            persist()
        }
    }

    private func finish() {
        timer = timer.pause(nowMs: Self.nowMs())
        ticker?.cancel()
        elapsedMs = timer.elapsedMs(nowMs: Self.nowMs())
        guard let finished = snapshot() else {
            return
        }
        newBest = store.complete(finished)
        saved = finished
        resultSaved = true
    }

    func restart() {
        guard let current = state, !current.isComplete else {
            return
        }
        state = current.restart()
        timer = GameTimer()
        elapsedMs = 0
        hintMessage = nil
        if visible {
            resumeTimer()
        }
        persist()
    }

    func hint() {
        guard let current = state, !current.isComplete, let found = current.findHint() else {
            return
        }
        if display.hintStyle == .fill {
            move { $0.placeHint(found) }
            return
        }
        var next = current
        next.selected = found.cell
        state = next
        hintMessage = found.message
    }

    func reveal() {
        guard let current = state, !current.isComplete, current.puzzle.solution != nil else {
            return
        }
        timer = timer.pause(nowMs: Self.nowMs())
        ticker?.cancel()
        state = current.revealSolution()
        revealed = true
        if let snapshot = snapshot() {
            store.reveal(snapshot)
        }
    }

    private func persist() {
        guard let state, !state.isComplete, !revealed, let snapshot = snapshot() else {
            return
        }
        store.save(snapshot)
    }

    private func snapshot() -> SudokuSavedGame? {
        guard let state, var game = saved else {
            return nil
        }
        game.values = state.values
        game.notes = state.notes
        game.mistakes = state.mistakes
        game.elapsedMs = timer.elapsedMs(nowMs: Self.nowMs())
        game.moves = state.undoStack
        return game
    }

    var board: SudokuBoardData? {
        guard let state else {
            return nil
        }
        var data = SudokuBoardData(state)
        data.boldPlacedDigits = display.isOn(.boldPlacedDigits)
        data.greyGivenCells = display.isOn(.greyGivenCells)
        return data
    }

    var doneDigits: Set<Int> {
        guard let state, display.isOn(.disableCompletedDigits) else {
            return []
        }
        return Set(state.puzzle.grid.digits.filter(state.isDigitDone))
    }

    var digitCounts: [Int] {
        guard let state, display.digitCounts != .off else {
            return []
        }
        return (0..<10).map { digit in
            display.digitCounts == .countDown
                ? max(state.puzzle.grid.size - state.digitCount(digit), 0)
                : state.digitCount(digit)
        }
    }
}

private enum SudokuPuzzleAction {
    case restart
    case reveal
}

private struct SudokuTourBounds: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    fileprivate func sudokuTourTarget(_ key: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SudokuTourBounds.self, value: [key: proxy.frame(in: .named("sudoku_game"))])
            })
    }
}

struct SudokuGameView: View {
    let id: Int
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @State private var menuOpen = false
    @State private var confirming: SudokuPuzzleAction?
    @State private var rulesOpen = false
    @State private var tourStep: Int?
    @State private var tourBounds: [String: CGRect] = [:]

    private static let rules = [
        "Fill the grid so every row, column and box has each number once.",
        "In killer sudoku the numbers in each dashed cage also add up to its total, with no number repeated in a cage.",
    ]
    private static let tutorial = [
        ("board", "Tap a cell to select it. Shaded cells are givens and can't change."),
        ("pad", "Then tap a number to place it. The pencil puts numbers in as notes, the eraser clears a cell."),
        ("hint", "Stuck? The bulb points at a cell you can fill next and says why."),
        ("menu", "Restart, show the solution and settings live in this menu."),
    ]

    var body: some View {
        if let model = navigator.model(id), let saved = model.saved, let state = model.state, let board = model.board {
            screen(model, saved, state, board)
                .onAppear(perform: model.onVisible)
                .onDisappear(perform: model.onHidden)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.onVisible()
                    } else {
                        model.onHidden()
                    }
                }
        }
    }

    private func screen(
        _ model: SudokuGameModel, _ saved: SudokuSavedGame, _ state: GameState, _ board: SudokuBoardData
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                header(model, saved, state)
                    .padding(.horizontal, 8)
                SudokuBoardView(board: board) { cell in
                    model.move { $0.tapCell(cell) }
                }
                .sudokuTourTarget("board")
                Text(model.hintMessage ?? "")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("hint_message")
                pad(model, state, board)
                    .padding(.horizontal, 8)
                    .sudokuTourTarget("pad")
                Spacer(minLength: 0)
            }
            if menuOpen {
                menu(model, state)
            }
            if let confirming {
                confirmDialog(model, confirming)
            }
            if rulesOpen {
                rulesDialog
            }
            if let tourStep {
                walkthrough(tourStep)
            }
            if model.resultSaved {
                SudokuWinDialog(model: model, saved: saved)
            }
        }
        .coordinateSpace(name: "sudoku_game")
        .onPreferenceChange(SudokuTourBounds.self) { tourBounds = $0 }
    }

    private func header(_ model: SudokuGameModel, _ saved: SudokuSavedGame, _ state: GameState) -> some View {
        let display = model.display
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                SudokuBackButton(action: navigator.home)
                Text(saved.title)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityIdentifier("game_title")
                Spacer()
                SudokuIconButton(symbol: "ellipsis", label: "Puzzle options", id: "puzzle_menu") { menuOpen = true }
                    .sudokuTourTarget("menu")
            }
            HStack(spacing: 12) {
                if state.countsMistakes && display.isOn(.showMistakeCount) {
                    Text("Mistakes: \(state.mistakes)")
                        .foregroundStyle(state.mistakes > 0 ? palette.wrong : Color.secondary)
                        .accessibilityIdentifier("mistakes")
                }
                if model.revealed {
                    Text("Solution shown")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("solution_shown")
                } else if display.isOn(.showTimer) {
                    Text(formatDuration(model.elapsedMs))
                        .font(.headline.monospacedDigit())
                        .accessibilityIdentifier("timer")
                }
                Spacer()
                HStack(spacing: 0) {
                    SudokuIconButton(
                        symbol: "arrow.uturn.backward", label: "Undo the last move", id: "undo",
                        enabled: !state.undoStack.isEmpty && !state.isComplete
                    ) { model.move { $0.undo() } }
                    SudokuIconButton(
                        symbol: "arrow.uturn.forward", label: "Redo the move you undid", id: "redo",
                        enabled: !state.redoStack.isEmpty && !state.isComplete
                    ) { model.move { $0.redo() } }
                    if display.isOn(.showHints) {
                        SudokuIconButton(
                            symbol: "lightbulb", label: "Show a hint", id: "hint",
                            enabled: !state.isComplete && !model.revealed, action: model.hint
                        )
                        .sudokuTourTarget("hint")
                    }
                    if display.isOn(.showTutorial) {
                        SudokuIconButton(symbol: "questionmark.circle", label: "Show the rules", id: "rules") {
                            rulesOpen = true
                        }
                    }
                }
            }
            .padding(.leading, 12)
        }
    }

    private func pad(_ model: SudokuGameModel, _ state: GameState, _ board: SudokuBoardData) -> some View {
        let digitFirst = state.inputMode == .digitFirst
        return SudokuPadView(
            digits: board.grid.digits,
            activeDigit: digitFirst ? state.activeDigit : nil,
            doneDigits: model.doneDigits,
            counts: model.digitCounts,
            tools: [
                SudokuPadTool(
                    symbol: "eraser",
                    description: digitFirst
                        ? "Eraser: tap cells to clear them, tap again to stop" : "Erase the selected cell",
                    tag: "erase", on: state.eraserActive, action: { model.move { $0.erase() } }),
                SudokuPadTool(
                    symbol: "pencil",
                    description: state.notesMode
                        ? "Notes on: numbers go in as pencil marks" : "Notes off: tap to add pencil marks",
                    tag: "notes", on: state.notesMode, action: { model.move { $0.toggleNotesMode() } }),
                SudokuPadTool(
                    symbol: "square.dashed",
                    description: digitFirst
                        ? "Mark: tap cells to box them in red, tap again to stop"
                        : "Box the selected cell in red, to remember where a trial started",
                    tag: "mark", on: state.markActive, action: { model.move { $0.mark() } }),
            ],
            onDigit: { digit in model.move { $0.tapDigit(digit) } }
        )
    }

    private func menu(_ model: SudokuGameModel, _ state: GameState) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { menuOpen = false }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                menuItem("Restart puzzle", id: "menu_restart", enabled: !state.isComplete) {
                    confirming = .restart
                }
                if model.display.isOn(.allowReveal) {
                    menuItem(
                        "Show solution", id: "menu_solution",
                        enabled: !state.isComplete && state.puzzle.solution != nil
                    ) { confirming = .reveal }
                }
                menuItem("Settings", id: "menu_settings", enabled: true) {
                    if let saved = model.saved {
                        navigator.push(.settings(saved.ref.mode))
                    }
                }
            }
            .frame(width: 220)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.thinLine))
            .padding(.top, 48)
            .padding(.trailing, 12)
        }
    }

    private func menuItem(_ title: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            menuOpen = false
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }

    private func confirmDialog(_ model: SudokuGameModel, _ action: SudokuPuzzleAction) -> some View {
        let restart = action == .restart
        return SudokuDialog(
            id: "puzzle_confirm", title: restart ? "Restart this puzzle?" : "Show the solution?",
            onDismiss: { confirming = nil }
        ) {
            Text(
                restart
                    ? "Your numbers, pencil marks, mistakes and time will be cleared."
                    : "This ends the game. It won't count towards best times or medals.")
            HStack {
                Spacer()
                SudokuTextButton(title: "Cancel", id: "confirm_cancel") { confirming = nil }
                SudokuTextButton(title: restart ? "Restart" : "Show solution", id: "confirm_action") {
                    confirming = nil
                    if restart {
                        model.restart()
                    } else {
                        model.reveal()
                    }
                }
            }
        }
    }

    private var rulesDialog: some View {
        SudokuDialog(id: "rules_dialog", title: "How to play", onDismiss: { rulesOpen = false }) {
            ForEach(Self.rules, id: \.self) { Text($0) }
            HStack {
                Spacer()
                SudokuTextButton(title: "Walk me through it", id: "walkthrough_start") {
                    rulesOpen = false
                    tourStep = 0
                }
                SudokuTextButton(title: "Got it", id: "rules_close") { rulesOpen = false }
            }
        }
    }

    private func walkthrough(_ index: Int) -> some View {
        let step = Self.tutorial[index]
        let last = index == Self.tutorial.count - 1
        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
                .onTapGesture { tourStep = nil }
            if let bounds = tourBounds[step.0] {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.accent, lineWidth: 4)
                    .frame(width: bounds.width + 8, height: bounds.height + 8)
                    .position(x: bounds.midX, y: bounds.midY)
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(index + 1) of \(Self.tutorial.count)").font(.caption)
                Text(step.1).accessibilityIdentifier("walkthrough_text")
                HStack {
                    Spacer()
                    SudokuTextButton(title: last ? "Close" : "Skip", id: "walkthrough_close") { tourStep = nil }
                    if index > 0 {
                        SudokuTextButton(title: "Back", id: "walkthrough_back") { tourStep = index - 1 }
                    }
                    if !last {
                        SudokuTextButton(title: "Next", id: "walkthrough_next") { tourStep = index + 1 }
                    }
                }
            }
            .padding(16)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walkthrough")
        }
    }
}

private struct SudokuWinDialog: View {
    let model: SudokuGameModel
    let saved: SudokuSavedGame
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        SudokuDialog(id: "solved_screen", onDismiss: navigator.home) {
            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(palette.background)
                    .frame(width: 64, height: 64)
                    .background(palette.accent, in: Circle())
                Text("Solved!").font(.title2.bold())
                if model.newBest {
                    Text("NEW BEST")
                        .font(.caption.bold())
                        .foregroundStyle(palette.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(palette.accent, in: Capsule())
                        .accessibilityIdentifier("new_best")
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                stat("Time", formatDuration(model.elapsedMs), id: "final_time")
                if model.display.isOn(.showMistakeCount) {
                    stat("Mistakes", "\(saved.mistakes)", id: nil)
                }
            }
            let left = dailiesLeft
            if !left.isEmpty {
                Text("STILL TO PLAY TODAY").font(.caption2).foregroundStyle(.secondary)
                HStack {
                    ForEach(left, id: \.self) { mode in
                        Button(mode.label) {
                            Task {
                                if let id = await SudokuStore.shared.openDaily(mode: mode, date: sudokuToday()) {
                                    navigator.openGame(id)
                                }
                            }
                        }
                        .accessibilityIdentifier("still_to_play_\(mode.slug)")
                    }
                }
            }
            HStack {
                Spacer()
                SudokuTextButton(title: "Home", id: "solved_home", action: navigator.home)
            }
        }
    }

    private var dailiesLeft: [GameMode] {
        let day = SudokuStore.shared.dailyResults[sudokuToday()]
        return GameMode.allCases.filter { (day?.status($0) ?? .notDone) == .notDone }
    }

    private func stat(_ label: String, _ value: String, id: String?) -> some View {
        VStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .accessibilityIdentifier(id ?? "")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
