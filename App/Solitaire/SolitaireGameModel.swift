import Foundation
import Observation
import SolitaireEngine

@MainActor
@Observable
final class SolitaireGameModel {
    private static let tick = Duration.milliseconds(500)
    private static let saveAfterIdle = Duration.milliseconds(400)
    private static let finishStep = Duration.milliseconds(110)
    private nonisolated static let checkLimit: TimeInterval = 2

    private(set) var game: GameState?
    private(set) var elapsedMs: Int64 = 0
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var unwinnable = false
    private(set) var findingLostMove = false
    private(set) var finishing = false
    private(set) var lastWinnableMove = 0
    private(set) var hintMessage: String?
    private(set) var title = ""
    private var warningDismissed = false

    @ObservationIgnored private let store: SolitaireStore
    @ObservationIgnored private var saved: SavedGame?
    @ObservationIgnored private var timer = GameTimer()
    @ObservationIgnored private var visible = false
    @ObservationIgnored private var ended = false
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var check: Task<Void, Never>?
    @ObservationIgnored private var lastWinnableMoves: Int?

    init(id: Int64, store: SolitaireStore = .shared) {
        self.store = store
        guard let loaded = store.game(id: id) else {
            return
        }
        saved = loaded
        title = loaded.deal.title
        game = GameState(
            start: loaded.deal.board,
            drawMode: loaded.deal.drawMode,
            moves: loaded.moves,
            oneTapMove: SolitairePreferences.current.oneTapMove,
            order: loaded.deal.order
        )
        timer = GameTimer(accumulatedMs: loaded.elapsedMs)
        elapsedMs = loaded.elapsedMs
        checkWinnable()
    }

    var moveCount: Int {
        game?.moveCount ?? 0
    }

    var isWon: Bool {
        game?.isWon ?? false
    }

    var canUndo: Bool {
        guard let game else {
            return false
        }
        return !game.moves.isEmpty && !game.isWon
    }

    var canFinish: Bool {
        (game?.canAutoFinish ?? false) && !finishing
    }

    var showUnwinnable: Bool {
        unwinnable && !warningDismissed && !isWon
    }

    var unwinnableText: String {
        let checked =
            "You've been through the whole stock with nothing new to play, "
            + "so the solver checked every line from here: none of them wins."
        if findingLostMove || lastWinnableMove == 0 {
            return checked
        }
        return "\(checked)\n\nIt could still be won up to move \(lastWinnableMove). "
            + "Move \(lastWinnableMove + 1) is where it slipped away."
    }

    var undoToWinnableLabel: String {
        if findingLostMove {
            return "Finding where it went wrong…"
        }
        if lastWinnableMove == 0 {
            return "Start the deal again"
        }
        return "Undo \(moveCount - lastWinnableMove) moves"
    }

    func applyPreferences() {
        game?.oneTapMove = SolitairePreferences.current.oneTapMove
        if check == nil {
            checkWinnable()
        }
    }

    func onStockClick() {
        move { $0.tapStock() }
    }

    func onCardClick(_ pile: Pile, _ index: Int) {
        move { $0.tapCard(pile, index: index) }
    }

    func onEmptyPileClick(_ pile: Pile) {
        move { $0.tapEmptyPile(pile) }
    }

    func onCardDrop(_ from: Pile, _ index: Int, _ to: Pile) {
        move { $0.drop(from: from, index: index, to: to) }
    }

    func onUndo() {
        move { $0.undo() }
    }

    func onFinish() {
        guard let current = game, !finishing else {
            return
        }
        let steps = current.autoFinishMoves()
        finishing = true
        Task { [weak self] in
            for step in steps {
                self?.move { $0.withMoves($0.moves + [step]) }
                try? await Task.sleep(for: Self.finishStep)
            }
            self?.finishing = false
        }
    }

    func onHint() {
        guard let current = game else {
            return
        }
        let fill = SolitairePreferences.current.hintFill
        switch current.findHint() {
        case nil:
            hintMessage = "No moves left."
        case .draw:
            if fill {
                move { $0.tapStock() }
            } else {
                hintMessage = "Nothing on the table can move, so draw from the stock."
            }
        case .transfer(let selection, let to):
            if fill {
                move { state in
                    state.drop(
                        from: selection.pile,
                        index: state.board.cardsIn(selection.pile).count - selection.count,
                        to: to
                    )
                }
            } else {
                game?.selection = selection
                hintMessage = hintText(board: current.board, selection: selection, to: to)
            }
        }
    }

    func onRestart() {
        guard let current = game, !current.isWon else {
            return
        }
        game = current.restart()
        hintMessage = nil
        timer = GameTimer()
        elapsedMs = 0
        if visible {
            resumeTimer()
        }
        persistNow()
        checkWinnable()
    }

    func newDeal() async -> Int64? {
        guard let deal = saved?.deal else {
            return nil
        }
        let seeds = await SolitaireDealer.winnableSeeds(
            drawMode: deal.drawMode,
            order: deal.order,
            enabled: SolitairePreferences.current.winnableOnly
        )
        persistNow()
        let next = DealRef.random(seed: SolitaireDealer.newSeed(), drawMode: deal.drawMode, order: deal.order, winnableSeeds: seeds)
        ended = true
        return store.start(next).id
    }

    func onVisible() {
        visible = true
        resumeTimer()
    }

    func onHidden() {
        guard visible else {
            return
        }
        visible = false
        timer = timer.pause(nowMs: Self.nowMs())
        ticker?.cancel()
        persistNow()
    }

    func onUndoToWinnable() {
        guard let current = game else {
            return
        }
        warningDismissed = false
        let target = Array(current.moves.prefix(lastWinnableMoves ?? 0))
        move { $0.withMoves(target) }
    }

    func giveUp() {
        check?.cancel()
        timer = timer.pause(nowMs: Self.nowMs())
        ticker?.cancel()
        pendingSave?.cancel()
        guard let lost = snapshot() else {
            return
        }
        ended = true
        store.lose(lost)
    }

    func onDismissUnwinnable() {
        warningDismissed = true
    }

    private func resumeTimer() {
        guard let current = game, !current.isWon else {
            return
        }
        timer = timer.start(nowMs: Self.nowMs())
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.publishTime()
                try? await Task.sleep(for: Self.tick)
            }
        }
    }

    private func publishTime() {
        elapsedMs = timer.elapsedMs(nowMs: Self.nowMs())
    }

    private func move(_ change: (GameState) -> GameState) {
        guard let before = game else {
            return
        }
        let after = change(before)
        if after == before {
            return
        }
        game = after
        hintMessage = nil
        if !before.isWon && after.isWon {
            finish()
        } else if after.moves != before.moves {
            persistSoon()
            checkWinnable()
        }
    }

    private func checkWinnable() {
        check?.cancel()
        check = nil
        unwinnable = false
        findingLostMove = false
        guard let current = game, SolitairePreferences.current.warnUnwinnable, !current.isWon, current.cycledStock,
            current.board.cardCount == Card.deck.count
        else {
            return
        }
        let moves = current.moves.count
        check = Task { [weak self] in
            let verdict = await Self.solve(current.board, current)
            guard let self, !Task.isCancelled else {
                return
            }
            switch verdict {
            case .winnable:
                lastWinnableMoves = moves
                lastWinnableMove = moves
            case .unwinnable:
                unwinnable = true
                findingLostMove = true
                let found = await Self.findLostMove(
                    current,
                    LostMoveSearch(winnable: min(lastWinnableMoves ?? 0, moves), lost: moves)
                )
                if Task.isCancelled {
                    return
                }
                lastWinnableMoves = found
                lastWinnableMove = found
                findingLostMove = false
            case .unknown:
                break
            }
        }
    }

    private nonisolated static func solve(_ board: Board, _ state: GameState) async -> Verdict {
        let drawMode = state.drawMode
        let order = state.order
        let task = Task.detached(priority: .userInitiated) {
            let started = ProcessInfo.processInfo.systemUptime
            return Solver.solve(board, drawMode: drawMode, order: order) {
                Task.isCancelled || ProcessInfo.processInfo.systemUptime - started > checkLimit
            }
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private nonisolated static func findLostMove(_ lost: GameState, _ start: LostMoveSearch) async -> Int {
        var search = start
        while let probe = search.probe {
            let board = lost.withMoves(Array(lost.moves.prefix(probe))).board
            search = search.narrow(probe: probe, verdict: await solve(board, lost))
        }
        return search.winnable
    }

    private func finish() {
        timer = timer.pause(nowMs: Self.nowMs())
        publishTime()
        ticker?.cancel()
        pendingSave?.cancel()
        guard let finished = snapshot() else {
            return
        }
        ended = true
        newBest = store.win(finished)
        resultSaved = true
    }

    private func persistSoon() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveAfterIdle)
            if !Task.isCancelled {
                self?.persistNow()
            }
        }
    }

    private func persistNow() {
        pendingSave?.cancel()
        guard !ended, let snapshot = snapshot() else {
            return
        }
        store.save(snapshot)
    }

    private func snapshot() -> SavedGame? {
        guard let game, var snapshot = saved else {
            return nil
        }
        snapshot.moves = game.moves
        snapshot.elapsedMs = timer.elapsedMs(nowMs: Self.nowMs())
        return snapshot
    }

    private static func nowMs() -> Int64 {
        Int64(ProcessInfo.processInfo.systemUptime * 1000)
    }
}
