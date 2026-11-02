import Foundation
import Observation
import PuzzlesCore
import SlideOutEngine

@Observable
@MainActor
final class SlideOutGameModel {
    let gameId: Int64
    private(set) var ref: PuzzleRef?
    private(set) var game: GameState?
    private(set) var hints = 0
    private(set) var elapsedMs: Int64 = 0
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var revealed = false

    @ObservationIgnored private var timer = GameTimer()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    init(gameId: Int64) {
        self.gameId = gameId
        guard let record = SlideOutStore.get(gameId), let ref = record.ref else {
            return
        }
        self.ref = ref
        game = GameState(puzzle: ref.puzzle, moves: (try? MoveCodec.decode(record.moves)) ?? [])
        hints = record.hints
        timer = GameTimer(accumulatedMs: record.elapsedMs)
        elapsedMs = record.elapsedMs
    }

    var moveCount: Int {
        game?.moves.count ?? 0
    }

    var par: Int {
        ref?.puzzle.par ?? 0
    }

    var isSolved: Bool {
        game?.isSolved ?? false
    }

    var canUndo: Bool {
        moveCount > 0 && !isSolved
    }

    var showSolvedDialog: Bool {
        isSolved && resultSaved
    }

    func slide(block: Int, to position: Int) {
        change { $0.slide(block, to: position) }
    }

    func undo() {
        change { $0.undo() }
    }

    func hint() async {
        guard let current = game, !current.isSolved else {
            return
        }
        if current.hint != nil {
            game = GameState(puzzle: current.puzzle, moves: current.moves)
            return
        }
        hints += 1
        persistSoon()
        let hinted = await Task.detached { current.withHint() }.value
        if game?.moves == current.moves {
            game = hinted
        }
    }

    func revealSolution() async {
        guard let current = game, !current.isSolved, !revealed else {
            return
        }
        revealed = true
        pauseTimer()
        pendingSave?.cancel()
        let shown = await Task.detached { current.revealSolution() }.value
        game = shown
        SlideOutStore.reveal(id: gameId, moves: shown.moves, elapsedMs: elapsedMs, hints: hints)
    }

    func restart() {
        guard let current = game, !current.isSolved else {
            return
        }
        game = current.restart()
        timer = GameTimer()
        elapsedMs = 0
        hints = 0
        resumeTimer()
        persistNow()
    }

    func newPuzzle() async throws -> Int64 {
        guard let level = ref?.level else {
            return gameId
        }
        let next = try await SlideOutBank.shared.random(level)
        persistNow()
        return SlideOutStore.start(next)
    }

    func onVisible() {
        resumeTimer()
    }

    func onHidden() {
        pauseTimer()
        persistNow()
    }

    private func change(_ update: (GameState) -> GameState) {
        guard !revealed, let before = game else {
            return
        }
        let after = update(before)
        if after == before {
            return
        }
        game = after
        if !before.isSolved && after.isSolved {
            finish(after)
        } else if after.moves != before.moves {
            persistSoon()
        }
    }

    private func finish(_ solved: GameState) {
        pauseTimer()
        pendingSave?.cancel()
        newBest = SlideOutStore.solve(id: gameId, moves: solved.moves, elapsedMs: elapsedMs, hints: hints)
        resultSaved = true
    }

    private func resumeTimer() {
        guard game != nil, !isSolved else {
            return
        }
        timer = timer.start(nowMs: Self.monotonicMs())
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func pauseTimer() {
        timer = timer.pause(nowMs: Self.monotonicMs())
        elapsedMs = timer.accumulatedMs
        ticker?.cancel()
    }

    private func tick() {
        elapsedMs = timer.elapsedMs(nowMs: Self.monotonicMs())
    }

    private func persistSoon() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled {
                self?.persistNow()
            }
        }
    }

    private func persistNow() {
        pendingSave?.cancel()
        guard let game, !game.isSolved else {
            return
        }
        tick()
        SlideOutStore.save(id: gameId, moves: game.moves, elapsedMs: elapsedMs, hints: hints)
    }

    private static func monotonicMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }
}
