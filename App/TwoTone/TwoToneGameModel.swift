import Foundation
import Observation
import TwoToneEngine

@MainActor
@Observable
final class TwoToneGameModel {
    private static let tick = Duration.milliseconds(500)

    private let store: TwoToneStore
    private let record: TwoToneGameRecord
    private(set) var game: GameState
    private(set) var hints: Int
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var elapsedMs: Int64

    private var timer: GameTimer
    private var ticker: Task<Void, Never>?

    init?(id: Int64, store: TwoToneStore) {
        guard let record = store.game(id: id), let ref = record.ref else {
            return nil
        }
        self.store = store
        self.record = record
        game = GameState.replay(puzzle: ref.puzzle, changes: ChangeCodec.decode(record.changes) ?? [])
        hints = record.hints
        elapsedMs = record.elapsedMs
        timer = GameTimer(accumulatedMs: record.elapsedMs)
    }

    var title: String {
        record.title
    }

    var size: Int {
        record.size
    }

    var canUndo: Bool {
        !game.changes.isEmpty && !game.isSolved
    }

    private var revealed: Bool {
        record.gameStatus == .revealed
    }

    private static func monotonicMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    func onTile(_ cell: Int) {
        move { $0.tap(cell) }
    }

    func onUndo() {
        move { $0.undo() }
    }

    func onHint() {
        guard !game.isSolved else {
            return
        }
        if game.hint != nil {
            game.hint = nil
        } else {
            game = game.withHint()
            hints += 1
            persist()
        }
    }

    func onReveal() {
        guard !game.isSolved else {
            return
        }
        stopTimer()
        game = game.revealSolution()
        writeProgress()
        store.finish(record, status: .revealed)
    }

    func onRestart() {
        guard !game.isSolved else {
            return
        }
        game = game.restart()
        timer = GameTimer()
        hints = 0
        elapsedMs = 0
        persist()
        if ticker != nil {
            onVisible()
        }
    }

    func onVisible() {
        guard !game.isSolved else {
            return
        }
        timer = timer.start(nowMs: Self.monotonicMs())
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshElapsed()
                try? await Task.sleep(for: Self.tick)
            }
        }
    }

    func onHidden() {
        stopTimer()
        persist()
    }

    private func refreshElapsed() {
        elapsedMs = timer.elapsedMs(nowMs: Self.monotonicMs())
    }

    private func stopTimer() {
        timer = timer.pause(nowMs: Self.monotonicMs())
        ticker?.cancel()
        ticker = nil
        refreshElapsed()
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
        if !before.isSolved && after.isSolved {
            finish()
        } else if after.changes != before.changes {
            persist()
        }
    }

    private func finish() {
        stopTimer()
        writeProgress()
        store.finish(record, status: .solved)
        newBest = store.isNewBest(record)
        resultSaved = true
    }

    private func persist() {
        guard !game.isSolved, record.gameStatus == .inProgress else {
            return
        }
        writeProgress()
    }

    private func writeProgress() {
        store.save(record, changes: game.changes, hints: hints, elapsedMs: timer.elapsedMs(nowMs: Self.monotonicMs()))
    }
}
