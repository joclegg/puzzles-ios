import CrosswordEngine
import PuzzlesCore
import SwiftUI

struct CrosswordGameView: View {
    let model: CrosswordGameModel
    let navigator: CrosswordNavigator

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var menuOpen = false
    @State private var revealing = false

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
                    }
                    clueLists
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            } else {
                board.padding(.horizontal, 8).padding(.top, 8)
                clueBar.padding(.horizontal, 8).padding(.top, 8)
                clueLists.padding(.horizontal, 8)
            }
        }
        .background(
            CrosswordKeyInput(active: !solved && !model.revealed, onKey: handle)
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
            CrosswordIconButton(symbol: "ellipsis", description: "More", tag: "game_menu") { menuOpen = true }
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
            onNew: { navigator.startRandom(size: model.saved.ref.size) }
        ) {
            Button("Home") { navigator.home() }.accessibilityIdentifier("solved_home")
        }
    }
}
