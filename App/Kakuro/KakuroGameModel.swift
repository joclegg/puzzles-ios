import Foundation
import KakuroEngine

@MainActor
@Observable
final class KakuroGameModel {
    private(set) var saved: SavedGame
    private(set) var game: GameState
    private(set) var elapsedMs: Int64
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var revealed = false
    private(set) var hintMessage: String?
    private(set) var settings = KakuroSettings()

    private var timer: GameTimer
    private var ticker: Task<Void, Never>?
    private var pendingSave: Task<Void, Never>?
    private var visible = false

    init(saved: SavedGame) {
        self.saved = saved
        var state = GameState.replay(puzzle: saved.ref.puzzle, changes: saved.changes)
        state.mistakes = saved.mistakes
        game = state
        elapsedMs = saved.elapsedMs
        timer = GameTimer(accumulatedMs: saved.elapsedMs)
        applySettings()
    }

    func applySettings() {
        settings = KakuroSettings()
        game.mistakeCheck = settings.mistakeCheck
        game.autoRemoveNotes = settings.isOn(.autoRemoveNotes)
        if game.inputMode != settings.inputMode {
            game = game.withInputMode(settings.inputMode)
        }
    }

    func tapCell(_ cell: Int) { move { $0.tapCell(cell) } }
    func tapDigit(_ digit: Int) { move { $0.tapDigit(digit) } }
    func erase() { move { $0.erase() } }
    func undo() { move { $0.undo() } }
    func redo() { move { $0.redo() } }
    func mark() { move { $0.mark() } }
    func toggleNotes() { move { $0.toggleNotes() } }

    func hint() {
        guard !game.isSolved, let hint = game.findHint() else {
            return
        }
        if settings.hintFill {
            move { $0.placeHint(hint) }
            return
        }
        game.selected = hint.cell
        hintMessage = hint.message
    }

    func revealSolution() {
        guard !game.isSolved, !revealed else {
            return
        }
        stopClock()
        pendingSave?.cancel()
        game = game.revealSolution()
        revealed = true
        KakuroStore.shared.reveal(snapshot())
    }

    func restart() {
        guard !game.isSolved else {
            return
        }
        game = game.restart()
        hintMessage = nil
        timer = GameTimer()
        elapsedMs = 0
        ticker?.cancel()
        if visible {
            resumeClock()
        }
        persistNow()
    }

    func onVisible() {
        visible = true
        applySettings()
        resumeClock()
    }

    func onHidden() {
        visible = false
        stopClock()
        persistNow()
    }

    func snapshot() -> SavedGame {
        var current = saved
        current.changes = game.changes
        current.mistakes = game.mistakes
        current.elapsedMs = timer.elapsedMs(nowMs: Self.monotonicNowMs())
        return current
    }

    private func move(_ change: (GameState) -> GameState) {
        guard !revealed else {
            return
        }
        let before = game
        let after = change(before)
        guard after != before else {
            return
        }
        game = after
        hintMessage = nil
        if !before.isSolved && after.isSolved {
            finish()
        } else if after.changes != before.changes || after.mistakes != before.mistakes {
            persistSoon()
        }
    }

    private func finish() {
        stopClock()
        pendingSave?.cancel()
        newBest = KakuroStore.shared.solve(snapshot())
        resultSaved = true
    }

    private func persistSoon() {
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else {
                return
            }
            persistNow()
        }
    }

    private func persistNow() {
        pendingSave?.cancel()
        guard !game.isSolved else {
            return
        }
        KakuroStore.shared.save(snapshot())
    }

    private func resumeClock() {
        guard !game.isSolved else {
            return
        }
        timer = timer.start(nowMs: Self.monotonicNowMs())
        ticker?.cancel()
        ticker = Task {
            while !Task.isCancelled {
                elapsedMs = timer.elapsedMs(nowMs: Self.monotonicNowMs())
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func stopClock() {
        timer = timer.pause(nowMs: Self.monotonicNowMs())
        elapsedMs = timer.elapsedMs(nowMs: Self.monotonicNowMs())
        ticker?.cancel()
    }

    private static func monotonicNowMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }
}
