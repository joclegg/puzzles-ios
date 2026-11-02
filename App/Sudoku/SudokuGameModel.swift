import PuzzlesCore
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
