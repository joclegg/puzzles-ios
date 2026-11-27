import CrosswordEngine
import PuzzlesCore
import SwiftUI

private struct CrosswordTourStep {
    let target: String
    let text: String
}

private struct CrosswordTourKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    fileprivate func crosswordTourTarget(_ key: String) -> some View {
        anchorPreference(key: CrosswordTourKey.self, value: .bounds) { [key: $0] }
    }
}

private let crosswordRules = [
    "Fill the grid with the answers to the clues.",
    "Tap a cell to pick it. Tap it again to switch between across and down.",
    "Type the answer with the keyboard.",
]

private func crosswordTutorial(hints: Bool) -> [CrosswordTourStep] {
    var steps = [
        CrosswordTourStep(
            target: "board",
            text: "Tap a cell to pick it. Tap it again to switch between across and down. Type the answer with the keyboard."
        ),
        CrosswordTourStep(
            target: "clue_bar", text: "This is the clue for the word you're on. The arrows move to the previous or next clue."),
    ]
    if hints {
        steps.append(CrosswordTourStep(target: "hint", text: "Stuck? The bulb tells you one letter and where it goes."))
    }
    steps.append(
        CrosswordTourStep(
            target: "menu", text: "Restart, new puzzle, reveal a letter, word or the puzzle, and settings live in this menu."))
    return steps
}

struct CrosswordGameView: View {
    let model: CrosswordGameModel
    let navigator: CrosswordNavigator

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var keyboardShown = false
    @State private var menuOpen = false
    @State private var revealing = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?

    private var game: GameState {
        model.game
    }

    private var settings: CrosswordSettings {
        model.settings
    }

    private var solved: Bool {
        game.isSolved
    }

    private var colors: CrosswordColors {
        CrosswordColors.of(scheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HelpersButton { navigator.path.append(.settings) }
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        board
                        clueBar
                        hintMessage
                    }
                    clueLists
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            } else {
                board.padding(.horizontal, 8).padding(.top, 8).layoutPriority(1)
                clueBar.padding(.horizontal, 8).padding(.top, 8)
                hintMessage
                if keyboardShown {
                    Spacer(minLength: 0)
                } else {
                    clueLists.padding(.horizontal, 8)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardShown = false
        }
        .background(
            CrosswordKeyInput(active: !solved && !model.revealed && !rulesOpen && tourStep == nil, onKey: handle)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .topTrailing) {
            if menuOpen {
                menu
            }
        }
        .overlay {
            if revealing {
                revealDialog
            }
        }
        .overlay {
            if rulesOpen {
                rulesDialog
            }
        }
        .overlayPreferenceValue(CrosswordTourKey.self) { anchors in
            if let tourStep {
                tour(index: tourStep, anchors: anchors)
            }
        }
        .overlay {
            if solved && model.resultSaved {
                CrosswordSolvedDialog(model: model, navigator: navigator)
            }
        }
        .task { await model.loadClues() }
        .onAppear(perform: model.onVisible)
        .onDisappear(perform: model.onHidden)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.onVisible()
            } else if phase == .background {
                model.onHidden()
            }
        }
    }

    private func handle(_ key: CrosswordKey) {
        switch key {
        case .letter(let character):
            model.type(character)
        case .backspace:
            model.backspace()
        case .space:
            model.toggleDirection()
        case .arrow(let arrow):
            model.arrow(arrow)
        case .tab(let backward):
            if backward {
                model.previousClue()
            } else {
                model.nextClue()
            }
        }
    }

    private var board: some View {
        CrosswordBoardView(game: game, onCell: model.tapCell)
            .frame(maxWidth: 560)
            .crosswordTourTarget("board")
    }

    private var header: some View {
        HStack(spacing: 0) {
            CrosswordBackButton { navigator.home() }
            VStack(alignment: .leading, spacing: 0) {
                Text(model.saved.ref.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if settings.isOn(.showTimer) {
                        ElapsedTimeText { model.elapsedMs }.accessibilityIdentifier("timer")
                    }
                    if settings.isOn(.showMistakes) {
                        Text("Mistakes \(game.mistakes)").accessibilityIdentifier("mistakes")
                    }
                }
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            CrosswordIconButton(
                symbol: "arrow.uturn.backward", description: "Undo the last letter", tag: "undo",
                enabled: !game.changes.isEmpty && !solved, action: model.undo)
            CrosswordIconButton(
                symbol: "arrow.uturn.forward", description: "Redo the letter you undid", tag: "redo",
                enabled: !game.undone.isEmpty && !solved, action: model.redo)
            if settings.isOn(.showHints) {
                CrosswordIconButton(
                    symbol: "lightbulb", description: "Show a hint", tag: "hint", enabled: !solved && !model.revealed,
                    action: model.hint
                )
                .crosswordTourTarget("hint")
            }
            CrosswordIconButton(symbol: "questionmark.circle", description: "Show the rules", tag: "rules") { rulesOpen = true }
            CrosswordIconButton(symbol: "ellipsis", description: "More", tag: "game_menu") { menuOpen = true }
                .crosswordTourTarget("menu")
        }
        .padding(.horizontal, 4)
    }

    private var clueBar: some View {
        HStack(spacing: 4) {
            CrosswordIconButton(symbol: "chevron.left", description: "Previous clue", tag: "clue_previous", enabled: !solved) {
                model.previousClue()
            }
            VStack(alignment: .leading, spacing: 2) {
                if let word = game.currentWord {
                    Text(word.label).font(.caption.weight(.semibold)).foregroundStyle(colors.accent)
                    Text(model.clueText(word)).font(.body).lineLimit(3).minimumScaleFactor(0.8)
                } else {
                    Text(" ").font(.body)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("clue_bar")
            CrosswordIconButton(symbol: "chevron.right", description: "Next clue", tag: "clue_next", enabled: !solved) {
                model.nextClue()
            }
        }
        .padding(.horizontal, 4)
        .background(colors.word, in: RoundedRectangle(cornerRadius: 12))
        .crosswordTourTarget("clue_bar")
    }

    private var hintMessage: some View {
        Text(model.hintMessage ?? "")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .accessibilityIdentifier("hint_message")
    }

    private var clueLists: some View {
        let words = Array(game.puzzle.words.enumerated())
        let current = game.currentWordIndex
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach([true, false], id: \.self) { across in
                        Text(across ? "Across" : "Down")
                            .font(.headline)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        ForEach(words.filter { $0.element.isAcross == across }, id: \.offset) { index, word in
                            clueRow(index: index, word: word, current: index == current)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .onChange(of: current) { _, index in
                if let index {
                    withAnimation { proxy.scrollTo(index, anchor: .center) }
                }
            }
        }
    }

    private func clueRow(index: Int, word: Word, current: Bool) -> some View {
        Button {
            model.selectWord(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(word.number)").font(.subheadline.weight(.semibold)).frame(minWidth: 24, alignment: .trailing)
                Text(model.clueText(word))
                    .font(.subheadline)
                    .foregroundStyle(game.isComplete(word) ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(current ? colors.word : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(solved)
        .id(index)
        .accessibilityIdentifier("clue_\(word.number)_\(word.isAcross ? "across" : "down")")
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private var menu: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { menuOpen = false }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                menuItem("Restart this puzzle", tag: "restart", enabled: !solved, action: model.restart)
                menuItem("New puzzle", tag: "new_puzzle", action: newPuzzle)
                if settings.isOn(.allowReveal) && !solved {
                    menuItem("Reveal letter", tag: "menu_reveal_letter", action: model.revealLetter)
                    menuItem("Reveal word", tag: "menu_reveal_word", action: model.revealWord)
                    menuItem("Reveal puzzle", tag: "menu_solution") { revealing = true }
                }
                menuItem("Settings", tag: "menu_settings") { navigator.path.append(.settings) }
            }
            .frame(width: 220)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding(.trailing, 8)
            .padding(.top, 44)
        }
    }

    private func menuItem(_ title: String, tag: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            menuOpen = false
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? Color.primary : Color.secondary)
        .accessibilityIdentifier(tag)
    }

    private func newPuzzle() {
        navigator.startRandom(size: model.saved.ref.size)
    }

    private var revealDialog: some View {
        CrosswordDialog(
            title: "Reveal the puzzle?",
            tag: nil,
            buttons: [
                CrosswordDialogButton(title: "Cancel", tag: nil) { revealing = false },
                CrosswordDialogButton(title: "Reveal puzzle", tag: "confirm_reveal") {
                    revealing = false
                    model.revealSolution()
                },
            ],
            onDismiss: { revealing = false }
        ) {
            Text("This ends the puzzle. It won't count towards best times.")
        }
    }
}

extension CrosswordGameView {
    fileprivate var rulesDialog: some View {
        CrosswordDialog(
            title: "How to play",
            tag: "rules_dialog",
            buttons: [
                CrosswordDialogButton(title: "Walk me through it", tag: "walkthrough_start") {
                    rulesOpen = false
                    tourStep = 0
                },
                CrosswordDialogButton(title: "Got it", tag: "rules_close") { rulesOpen = false },
            ],
            onDismiss: { rulesOpen = false }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(crosswordRules, id: \.self) { Text($0) }
            }
        }
    }

    fileprivate func tour(index: Int, anchors: [String: Anchor<CGRect>]) -> some View {
        let steps = crosswordTutorial(hints: settings.isOn(.showHints))
        let step = steps[min(index, steps.count - 1)]
        let last = index >= steps.count - 1
        return GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { tourStep = nil }
                    .accessibilityHidden(true)
                if let anchor = anchors[step.target] {
                    let rect = proxy[anchor]
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colors.accent, lineWidth: 4)
                        .frame(width: rect.width + 12, height: rect.height + 12)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step \(index + 1) of \(steps.count)").font(.caption2)
                    Text(step.text).accessibilityIdentifier("walkthrough_text")
                    HStack(spacing: 16) {
                        Spacer()
                        Button(last ? "Close" : "Skip") { tourStep = nil }.accessibilityIdentifier("walkthrough_close")
                        if index > 0 {
                            Button("Back") { tourStep = index - 1 }.accessibilityIdentifier("walkthrough_back")
                        }
                        if !last {
                            Button("Next") { tourStep = index + 1 }.accessibilityIdentifier("walkthrough_next")
                        }
                    }
                    .foregroundStyle(colors.accent)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(16)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("walkthrough")
            }
        }
    }
}

private struct CrosswordSolvedDialog: View {
    let model: CrosswordGameModel
    let navigator: CrosswordNavigator

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WinDialog(
            title: "Solved!",
            accent: CrosswordColors.of(scheme).accent,
            dailyGroup: "CROSSWORD",
            newBest: model.newBest,
            stats: [WinStat(label: "Time", value: formatDuration(model.elapsedMs), tag: "solved_time")],
            tag: "solved_dialog",
            newLabel: sizeName(model.saved.ref.size),
            newTag: "solved_new_puzzle",
            shareText: SettingsTab.crossword.winShareText(puzzleId: model.saved.ref.id),
            onNew: { navigator.startRandom(size: model.saved.ref.size) }
        ) {
            Button("Home") { navigator.home() }.accessibilityIdentifier("solved_home")
        }
    }
}
