import SudokuEngine
import SwiftUI

private enum SudokuEntryProblem {
    case clash
    case noSolution
    case multipleSolutions
    case tooHard

    var unverifiedMessage: String? {
        switch self {
        case .clash:
            nil
        case .noSolution:
            "This puzzle has no answer, so there may be a typo."
        case .multipleSolutions:
            "This puzzle has more than one answer."
        case .tooHard:
            "Checking this puzzle would take too long."
        }
    }
}

private struct SudokuEntryCheck: Sendable {
    let puzzle: Puzzle
    var clash = false
    var noSolution = false
    var multiple = false
    var tooHard = false
    var level: Difficulty?

    var problem: SudokuEntryProblem? {
        if clash {
            return .clash
        }
        if noSolution {
            return .noSolution
        }
        if multiple {
            return .multipleSolutions
        }
        return tooHard ? .tooHard : nil
    }
}

private func sudokuCheckEntry(givens: [Int], cages: [Cage]) -> SudokuEntryCheck {
    let unverified = Puzzle(givens: givens, solution: nil, cages: cages)
    let solver = Solver(givens: givens, cages: cages)
    if !solver.consistent {
        return SudokuEntryCheck(puzzle: unverified, clash: true)
    }
    switch solver.countSolutionsWithin(limit: 2, maxSteps: 3_000_000) {
    case 0:
        return SudokuEntryCheck(puzzle: unverified, noSolution: true)
    case 1:
        let solved = Puzzle(givens: givens, solution: Solver(givens: givens, cages: cages).solve(), cages: cages)
        var grader = Grader(givens: givens, cages: cages)
        return SudokuEntryCheck(puzzle: solved, level: grader.grade().level)
    case nil:
        return SudokuEntryCheck(puzzle: unverified, tooHard: true)
    default:
        return SudokuEntryCheck(puzzle: unverified, multiple: true)
    }
}

@MainActor
@Observable
private final class SudokuEntryModel {
    private static let separator = "#"

    var mode: GameMode
    private(set) var entry: GameState
    private(set) var cages = CageBuilder()
    private(set) var cageTool = false
    private(set) var cageProblem: CageProblem?
    private(set) var problem: SudokuEntryProblem?
    private(set) var checking = false

    init(mode: GameMode) {
        self.mode = mode
        let blank = Puzzle(givens: SudokuGrid.standard.emptyValues(), solution: nil)
        var state = GameState(puzzle: blank, mistakeCheck: .off)
        state.options = sudokuModeSettings(mode).playOptions
        entry = state.withInputMode(sudokuInputMode())
        if let draft = UserDefaults.standard.string(forKey: SettingKeys.customDraft) {
            restore(draft)
        }
    }

    private func restore(_ draft: String) {
        let pieces = draft.split(separator: Self.separator, maxSplits: 1).map(String.init)
        guard let encoded = pieces.last, let puzzle = try? PuzzleCodec.decode(encoded) else {
            return
        }
        if pieces.first == GameMode.killer.rawValue {
            mode = .killer
        }
        entry.values = puzzle.givens
        cages = CageBuilder(cages: puzzle.cages)
    }

    private var activeCages: [Cage] {
        mode == .killer ? cages.cages : []
    }

    func setMode(_ newMode: GameMode) {
        mode = newMode
        if mode == .classic {
            cageTool = false
        }
        problem = nil
        saveDraft()
    }

    func toggleCageTool() {
        cageTool.toggle()
        cageProblem = nil
    }

    func tapCell(_ cell: Int) {
        if cageTool {
            editCages { $0.tapCell(cell) }
        } else {
            edit { $0.tapCell(cell) }
        }
    }

    func tapDigit(_ digit: Int) {
        if cageTool {
            editCages { $0.typeDigit(digit) }
        } else {
            edit { $0.tapDigit(digit) }
        }
    }

    func erase() {
        if cageTool {
            editCages { $0.deleteSelection() }
        } else {
            edit { $0.erase() }
        }
    }

    func confirmCage() {
        cageProblem = cages.problem()
        editCages { $0.confirm() }
    }

    func clear() {
        cages = CageBuilder()
        edit { state in
            var next = state
            next.values = SudokuGrid.standard.emptyValues()
            return next
        }
    }

    func dismissProblem() {
        problem = nil
    }

    func fix(playUnverified: Bool) async -> Int? {
        let givens = entry.values
        let cageList = activeCages
        checking = true
        let result = await Task.detached(priority: .userInitiated) {
            sudokuCheckEntry(givens: givens, cages: cageList)
        }.value
        checking = false
        if let found = result.problem, found == .clash || !playUnverified {
            problem = found
            return nil
        }
        let ref = PuzzleRef(
            id: "custom:\(PuzzleCodec.encode(result.puzzle))", mode: mode, difficulty: result.level,
            puzzle: result.puzzle, custom: true)
        let game = SudokuStore.shared.start(ref, mistakeCheck: sudokuModeSettings(mode).mistakeCheck)
        UserDefaults.standard.removeObject(forKey: SettingKeys.customDraft)
        return game.id
    }

    private func edit(_ change: (GameState) -> GameState) {
        let next = change(entry)
        if next == entry {
            return
        }
        let changed = next.values != entry.values
        entry = next
        problem = nil
        if changed {
            saveDraft()
        }
    }

    private func editCages(_ change: (CageBuilder) -> CageBuilder) {
        let next = change(cages)
        let changed = next.cages != cages.cages
        cages = next
        problem = nil
        if changed {
            cageProblem = nil
            saveDraft()
        }
    }

    private func saveDraft() {
        let encoded = PuzzleCodec.encode(Puzzle(givens: entry.values, solution: nil, cages: cages.cages))
        UserDefaults.standard.set("\(mode.rawValue)\(Self.separator)\(encoded)", forKey: SettingKeys.customDraft)
    }

    var givenCount: Int {
        entry.values.count { $0 != 0 }
    }

    var canFix: Bool {
        !checking && (givenCount > 0 || !activeCages.isEmpty)
    }

    var board: SudokuBoardData {
        let cageList = activeCages
        let clashes = conflicts(values: entry.values, cages: cageList)
        var state = entry
        state.puzzle = Puzzle(givens: SudokuGrid.standard.emptyValues(), solution: nil, cages: cageList)
        var data = SudokuBoardData(state)
        let selection = Set(cages.selection)
        for cell in data.cells.indices {
            data.cells[cell].wrong = clashes.contains(cell)
            if cageTool {
                data.cells[cell].highlight = selection.contains(cell) ? .selected : .none
            }
        }
        return data
    }
}

struct SudokuEntryView: View {
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette
    @State private var model: SudokuEntryModel

    init(mode: GameMode) {
        _model = State(initialValue: SudokuEntryModel(mode: mode))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    SudokuBackButton(action: navigator.back)
                    Text("Enter puzzle").font(.headline)
                    Spacer()
                    Text(
                        model.cageTool
                            ? "Cage sum: \(model.cages.sumInput.isEmpty ? "–" : model.cages.sumInput)" : "\(model.givenCount) numbers"
                    )
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("entry_status")
                }
                .padding(.horizontal, 12)
                SudokuSegments(
                    options: GameMode.allCases, selected: model.mode, label: \.label, id: { "entry_\($0.slug)" },
                    onSelect: { model.setMode($0) }
                )
                .padding(.horizontal, 12)
                SudokuBoardView(board: model.board, onCell: { model.tapCell($0) })
                SudokuPadView(
                    activeDigit: model.entry.inputMode == .digitFirst && !model.cageTool ? model.entry.activeDigit : nil,
                    counts: model.cageTool ? [] : (0..<10).map { model.entry.digitCount($0) },
                    tools: tools,
                    onDigit: { model.tapDigit($0) }
                )
                .padding(.horizontal, 8)
                if let text = problemText {
                    Text(text)
                        .foregroundStyle(palette.wrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .accessibilityIdentifier("entry_problem")
                }
                Button {
                    fix(playUnverified: false)
                } label: {
                    Text(model.checking ? "Checking…" : "Fix puzzle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canFix)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("fix_puzzle")
                Spacer(minLength: 0)
            }
            if let message = model.problem?.unverifiedMessage {
                SudokuDialog(id: "unverified_dialog", title: "Can't confirm one answer", onDismiss: model.dismissProblem) {
                    Text("\(message) You can still play it. Wrong numbers can't be shown, but clashes can still be blocked.")
                    HStack {
                        Spacer()
                        SudokuTextButton(title: "Keep editing", id: "keep_editing", action: model.dismissProblem)
                        SudokuTextButton(title: "Play anyway", id: "play_anyway") { fix(playUnverified: true) }
                    }
                }
            }
        }
    }

    private var problemText: String? {
        if model.problem == .clash {
            return "Some numbers clash. Fix the red cells."
        }
        switch model.cageProblem {
        case .notConnected:
            return "A cage's cells must touch each other."
        case .impossibleSum:
            return "No set of different numbers makes that sum."
        case .empty:
            return "Pick the cage's cells and type its sum first."
        case nil:
            return nil
        }
    }

    private var tools: [SudokuPadTool] {
        var list: [SudokuPadTool] = []
        if model.mode == .killer {
            list.append(
                SudokuPadTool(
                    symbol: "square.dashed",
                    description: model.cageTool ? "Cages on: tap neighbouring cells, type the sum, then tick" : "Draw cages",
                    tag: "cage_tool", on: model.cageTool, action: { model.toggleCageTool() }))
        }
        if model.cageTool {
            list.append(
                SudokuPadTool(symbol: "checkmark", description: "Save this cage", tag: "confirm_cage", action: { model.confirmCage() }))
            list.append(SudokuPadTool(symbol: "eraser", description: "Delete the selected cage", tag: "erase", action: { model.erase() }))
        } else {
            list.append(SudokuPadTool(symbol: "eraser", description: "Erase the selected cell", tag: "erase", action: { model.erase() }))
            list.append(SudokuPadTool(symbol: "trash", description: "Clear the whole grid", tag: "clear", action: { model.clear() }))
        }
        return list
    }

    private func fix(playUnverified: Bool) {
        Task {
            if let id = await model.fix(playUnverified: playUnverified) {
                navigator.openGame(id)
            }
        }
    }
}
