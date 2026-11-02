import KakuroEngine
import PuzzlesCore
import SwiftUI

private struct KakuroTourStep {
    let target: String
    let text: String
}

private struct KakuroTourKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    fileprivate func kakuroTourTarget(_ key: String) -> some View {
        anchorPreference(key: KakuroTourKey.self, value: .bounds) { [key: $0] }
    }
}

private let kakuroRules = [
    "Fill each white cell with a digit from 1 to 9.",
    "The number above a diagonal is the sum of the run to its right; below it, the run beneath.",
    "A digit can't repeat within a run.",
]

private let kakuroTutorial = [
    KakuroTourStep(
        target: "board", text: "Each white cell takes a digit from 1 to 9. A clue is the sum of the run to its right or below it."),
    KakuroTourStep(target: "hint", text: "Stuck? The bulb shows you the next step."),
    KakuroTourStep(target: "menu", text: "Restart, show the solution and settings live in this menu."),
]

struct KakuroGameView: View {
    let model: KakuroGameModel
    let navigator: KakuroNavigator

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var menuOpen = false
    @State private var revealing = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?

    private var game: GameState {
        model.game
    }

    private var settings: KakuroSettings {
        model.settings
    }

    private var solved: Bool {
        game.isSolved
    }

    private var digitFirst: Bool {
        game.inputMode == .digitFirst
    }

    private var colors: KakuroColors {
        KakuroColors.of(scheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HelpersButton { navigator.path.append(.settings) }
            KakuroBoardView(
                game: game,
                highlightRuns: settings.isOn(.highlightRuns),
                onCell: model.tapCell
            )
            .kakuroTourTarget("board")
            .padding(.horizontal, 8)
            .padding(.top, 24)
            Text(model.hintMessage ?? "")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .accessibilityIdentifier("hint_message")
            if settings.isOn(.showCombinations) {
                combinations.padding(.top, 12)
            }
            Spacer(minLength: 8)
            pad
        }
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
        .overlay {
            if solved && model.resultSaved {
                KakuroSolvedDialog(model: model, navigator: navigator)
            }
        }
        .overlayPreferenceValue(KakuroTourKey.self) { anchors in
            if let tourStep {
                tour(index: tourStep, anchors: anchors)
            }
        }
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

    private var header: some View {
        HStack(spacing: 0) {
            KakuroBackButton { navigator.home() }
            VStack(alignment: .leading, spacing: 0) {
                Text(model.saved.ref.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if settings.isOn(.showTimer) {
                        Text(formatDuration(model.elapsedMs)).accessibilityIdentifier("timer")
                    }
                    if settings.isOn(.showMistakeCount) && game.mistakeCheck != .off {
                        Text("Mistakes \(game.mistakes)").accessibilityIdentifier("mistakes")
                    }
                }
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            KakuroIconButton(
                symbol: "arrow.uturn.backward", description: "Undo the last tap", tag: "undo",
                enabled: !game.changes.isEmpty && !solved, action: model.undo)
            KakuroIconButton(
                symbol: "arrow.uturn.forward", description: "Redo the tap you undid", tag: "redo",
                enabled: !game.undone.isEmpty && !solved, action: model.redo)
            if settings.isOn(.showHints) {
                KakuroIconButton(symbol: "lightbulb", description: "Show a hint", tag: "hint", enabled: !solved, action: model.hint)
                    .kakuroTourTarget("hint")
            }
            if settings.isOn(.showTutorial) {
                KakuroIconButton(symbol: "questionmark.circle", description: "Show the rules", tag: "rules") { rulesOpen = true }
            }
            KakuroIconButton(symbol: "ellipsis", description: "More", tag: "game_menu") { menuOpen = true }
                .kakuroTourTarget("menu")
        }
        .padding(.horizontal, 4)
    }

    private var combinations: some View {
        VStack(spacing: 2) {
            ForEach(Array(game.combinationLines(order: settings.combinationOrder).enumerated()), id: \.offset) { _, line in
                combinationText(line)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("combinations")
            }
        }
    }

    private func combinationText(_ line: CombinationLine) -> Text {
        var text = AttributedString(line.header)
        if line.sets.isEmpty {
            text += AttributedString("none fit")
        }
        for (index, digits) in line.sets.enumerated() {
            if index > 0 {
                text += AttributedString("  ")
            }
            for digit in digits {
                var part = AttributedString("\(digit.digit)")
                if digit.placed {
                    part.inlinePresentationIntent = .stronglyEmphasized
                }
                text += part
            }
        }
        return Text(text)
    }

    private var pad: some View {
        let done = settings.isOn(.greyUsedDigits) ? game.doneDigits : []
        return KakuroNumberPad(
            activeDigit: game.activeDigit,
            doneDigits: done,
            tools: [
                KakuroPadTool(
                    symbol: "eraser",
                    description: !digitFirst
                        ? "Clear the selected cell"
                        : game.eraserActive ? "Erase is on: tap cells to clear them" : "Turn on erase, then tap cells to clear them",
                    tag: "erase",
                    on: game.eraserActive,
                    action: model.erase
                ),
                KakuroPadTool(
                    symbol: "pencil",
                    description: game.notesMode ? "Notes are on: digits go in as notes" : "Notes are off: digits go in as answers",
                    tag: "notes",
                    on: game.notesMode,
                    action: model.toggleNotes
                ),
                KakuroPadTool(
                    symbol: "square",
                    description: digitFirst
                        ? "Mark: tap cells to box them in red, tap again to stop"
                        : "Box the selected cell in red, to remember where a trial started",
                    tag: "mark",
                    on: game.markActive,
                    action: model.mark
                ),
            ],
            onDigit: model.tapDigit
        )
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 16)
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
                    menuItem("Show solution", tag: "menu_solution") { revealing = true }
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
        KakuroDialog(
            title: "Show the solution?",
            tag: nil,
            buttons: [
                KakuroDialogButton(title: "Cancel", tag: nil) { revealing = false },
                KakuroDialogButton(title: "Show solution", tag: "confirm_reveal") {
                    revealing = false
                    model.revealSolution()
                },
            ],
            onDismiss: { revealing = false }
        ) {
            Text("This ends the puzzle. It won't count towards best times.")
        }
    }

    private var rulesDialog: some View {
        KakuroDialog(
            title: "How to play",
            tag: nil,
            buttons: [
                KakuroDialogButton(title: "Walk me through it", tag: "walkthrough_start") {
                    rulesOpen = false
                    tourStep = 0
                },
                KakuroDialogButton(title: "Got it", tag: "rules_close") { rulesOpen = false },
            ],
            onDismiss: { rulesOpen = false }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(kakuroRules, id: \.self) { Text($0) }
            }
        }
    }

    private func tour(index: Int, anchors: [String: Anchor<CGRect>]) -> some View {
        let step = kakuroTutorial[index]
        let last = index == kakuroTutorial.count - 1
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
                    Text("Step \(index + 1) of \(kakuroTutorial.count)").font(.caption2)
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

private struct KakuroSolvedDialog: View {
    let model: KakuroGameModel
    let navigator: KakuroNavigator

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        WinDialog(
            title: "Solved!",
            accent: KakuroColors.of(scheme).accent,
            dailyGroup: "KAKURO",
            newBest: model.newBest,
            stats: [WinStat(label: "Time", value: formatDuration(model.elapsedMs), tag: "solved_time")],
            tag: "solved_dialog",
            newLabel: sizeLabel(model.saved.ref.size),
            newTag: "solved_new_puzzle",
            onNew: { navigator.startRandom(size: model.saved.ref.size) }
        ) {
            Button("Home") { navigator.home() }.accessibilityIdentifier("solved_home")
        }
    }
}
