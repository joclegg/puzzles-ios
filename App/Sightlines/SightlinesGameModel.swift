import Foundation
import PuzzlesCore
import SightlinesEngine

@MainActor
@Observable
final class SightlinesGameModel {
    private static let tickMs = 500
    private static let saveAfterIdleMs = 400

    private(set) var game: GameState?
    var colour = Dot.blue
    private(set) var title = ""
    private(set) var elapsedMs: Int64 = 0
    private(set) var hints = 0
    private(set) var newBest = false
    private(set) var resultSaved = false

    private let store: SightlinesStore
    private var saved: SavedGame?
    private var timer = GameTimer()
    private var visible = false
    private var revealed = false
    private var closed = false
    private var ticker: Task<Void, Never>?
    private var pendingSave: Task<Void, Never>?

    init(id: Int64, store: SightlinesStore) {
        self.store = store
        guard let loaded = store.game(id: id) else {
            return
        }
        saved = loaded
        game = GameState.replay(puzzle: loaded.ref.puzzle, changes: loaded.changes)
        title = loaded.ref.title
        hints = loaded.hints
        elapsedMs = loaded.elapsedMs
        timer = GameTimer(accumulatedMs: loaded.elapsedMs)
    }

    private var nowMs: Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    var size: Int? {
        saved?.ref.size
    }

    var canUndo: Bool {
        guard let game else {
            return false
        }
        return !game.changes.isEmpty && !game.isSolved
    }

    var solved: Bool {
        game?.isSolved ?? false
    }

    func onDot(_ cell: Int, pickColour: Bool) {
        move { pickColour ? $0.paint(cell, colour: colour) : $0.tap(cell) }
    }

    func onUndo() {
        move { $0.undo() }
    }

    func onHint() {
        guard var current = game, !current.isSolved else {
            return
        }
        if current.hint != nil {
            current.hint = nil
            game = current
        } else {
            game = current.withHint()
            hints += 1
            persistSoon()
        }
    }

    func onReveal() {
        guard let current = game, !current.isSolved, !revealed else {
            return
        }
        timer = timer.pause(nowMs: nowMs)
        elapsedMs = timer.elapsedMs(nowMs: nowMs)
        stopTasks()
        game = current.revealSolution()
        revealed = true
        if let snapshot {
            store.reveal(snapshot)
        }
    }

    func onRestart() {
        guard let current = game, !current.isSolved else {
            return
        }
        game = current.restart()
        timer = GameTimer()
        elapsedMs = 0
        hints = 0
        if visible {
            resumeTimer()
        }
        persistNow()
    }

    func closeForNewPuzzle() {
        persistNow()
        stopTasks()
        closed = true
    }

    func onVisible() {
        visible = true
        resumeTimer()
    }

    func onHidden() {
        visible = false
        timer = timer.pause(nowMs: nowMs)
        ticker?.cancel()
        persistNow()
    }

    private func resumeTimer() {
        guard let game, !game.isSolved, !closed else {
            return
        }
        timer = timer.start(nowMs: nowMs)
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                self.elapsedMs = self.timer.elapsedMs(nowMs: self.nowMs)
                try? await Task.sleep(for: .milliseconds(Self.tickMs))
            }
        }
    }

    private func move(_ change: (GameState) -> GameState) {
        guard !revealed, let before = game else {
            return
        }
        let after = change(before)
        guard after != before else {
            return
        }
        game = after
        if !before.isSolved && after.isSolved {
            finish()
        } else if after.changes != before.changes {
            persistSoon()
        }
    }

    private func finish() {
        timer = timer.pause(nowMs: nowMs)
        elapsedMs = timer.elapsedMs(nowMs: nowMs)
        stopTasks()
        guard let snapshot else {
            return
        }
        newBest = store.solve(snapshot)
        resultSaved = true
    }

    private func persistSoon() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.saveAfterIdleMs))
            if !Task.isCancelled {
                self?.persistNow()
            }
        }
    }

    private func persistNow() {
        pendingSave?.cancel()
        guard !closed, let snapshot, game?.isSolved != true else {
            return
        }
        store.save(snapshot)
    }

    private func stopTasks() {
        ticker?.cancel()
        pendingSave?.cancel()
    }

    private var snapshot: SavedGame? {
        guard let game, var copy = saved else {
            return nil
        }
        copy.changes = game.changes
        copy.hints = hints
        copy.elapsedMs = timer.elapsedMs(nowMs: nowMs)
        return copy
    }
}
