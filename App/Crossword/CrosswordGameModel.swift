import Foundation
import CrosswordEngine
import PuzzlesCore

@MainActor
@Observable
final class CrosswordGameModel {
    private(set) var saved: SavedGame
    private(set) var game: GameState
    private(set) var elapsedMs: Int64
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var revealed = false
    private(set) var clues: [String: String] = [:]
    private(set) var settings = CrosswordSettings()
    private(set) var hintMessage: String?

    private var timer: GameTimer
    private var ticker: Task<Void, Never>?
    private var pendingSave: Task<Void, Never>?
    private var visible = false

    init(saved: SavedGame) {
        self.saved = saved
        var state = GameState.start(puzzle: saved.ref.puzzle, entries: saved.entries, changes: saved.changes)
        state.mistakes = saved.mistakes
        state.hints = saved.hints
        game = state
        elapsedMs = saved.elapsedMs
        timer = GameTimer(accumulatedMs: saved.elapsedMs)
        applySettings()
    }

    func applySettings() {
        settings = CrosswordSettings()
        game.skipFilledCells = settings.isOn(.skipFilledCells)
        game.showMistakes = settings.isOn(.showMistakes)
    }

    func loadClues() async {
        guard clues.isEmpty else {
            return
        }
        clues = await attempt("Crossword clues") { try await CrosswordBank.clues() } ?? [:]
    }

    func clueText(_ word: Word) -> String {
        ClueBook.text(for: word, in: game.puzzle, clues: clues)
    }

    func tapCell(_ cell: Int) { move { $0.tapCell(cell) } }
    func type(_ character: Character) { move { $0.type(character) } }
    func backspace() { move { $0.backspace() } }
    func toggleDirection() { move { $0.toggleDirection() } }
    func arrow(_ arrow: Arrow) { move { $0.arrow(arrow) } }
    func nextClue() { move { $0.nextClue() } }
    func previousClue() { move { $0.previousClue() } }
    func selectWord(_ index: Int) { move { $0.selectWord(index) } }
    func undo() { move { $0.undo() } }
    func redo() { move { $0.redo() } }
    func revealLetter() { move { $0.revealLetter() } }
    func revealWord() { move { $0.revealWord() } }

    func hint() {
        guard !game.isSolved, !revealed, let hint = game.findHint() else {
            return
        }
        if settings.hintFill {
            move { $0.placeHint(hint) }
            return
        }
        move { $0.pointHint(hint) }
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
        CrosswordStore.shared.reveal(snapshot())
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
        current.entries = game.entries
        current.changes = game.changes
        current.mistakes = game.mistakes
        current.hints = game.hints
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
        } else if after.entries != before.entries || after.mistakes != before.mistakes
            || after.hints != before.hints
        {
            persistSoon()
        }
    }

    private func finish() {
        stopClock()
        pendingSave?.cancel()
        newBest = CrosswordStore.shared.solve(snapshot())
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
        CrosswordStore.shared.save(snapshot())
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
