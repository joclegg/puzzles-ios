import Foundation
import Observation
import WordWheelEngine

@MainActor
@Observable
final class WordWheelGameModel {
    private(set) var saved: SavedGame?
    private(set) var game: GameState?
    private(set) var chosen: [Int] = []
    private(set) var elapsedMs: Int64 = 0
    private(set) var newBest = false
    private(set) var resultSaved = false
    private(set) var revealedAll = false

    @ObservationIgnored private let id: Int64
    @ObservationIgnored private let store = WordWheelStore.shared
    @ObservationIgnored private var words: WordList?
    @ObservationIgnored private var elapsedBase: Int64 = 0
    @ObservationIgnored private var runningSince: TimeInterval?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(id: Int64) {
        self.id = id
    }

    func load() async {
        guard game == nil, let loaded = store.game(id: id), let list = try? await WordWheelBank.shared.words()
        else {
            return
        }
        words = list
        saved = loaded
        elapsedBase = loaded.elapsedMs
        elapsedMs = elapsed
        game = GameState(puzzle: loaded.ref.puzzle, found: loaded.found, bonus: loaded.bonus, revealed: loaded.revealed)
    }

    var title: String {
        saved?.ref.title ?? ""
    }

    var isSolved: Bool {
        game?.isSolved ?? false
    }

    var currentText: String {
        guard let game else {
            return ""
        }
        if chosen.isEmpty {
            return game.last?.message ?? ""
        }
        let letters = Array(game.wheel)
        return String(chosen.map { letters[$0] })
    }

    var wordsLeft: Int {
        guard let game else {
            return 0
        }
        return game.puzzle.crossword.words.filter { !game.found.contains($0) }.count
    }

    var foundCells: Set<Cell> {
        guard let game else {
            return []
        }
        return Set(
            game.puzzle.crossword.placements
                .filter { game.found.contains($0.word) }
                .flatMap(\.cells)
        )
    }

    var hintedCells: Set<Cell> {
        Set(game?.revealed ?? []).subtracting(foundCells)
    }

    func setChosen(_ indices: [Int]) {
        chosen = indices
    }

    func submit() {
        guard let game, let words else {
            return
        }
        let letters = Array(game.wheel)
        let word = String(chosen.map { letters[$0] })
        chosen = []
        guard !word.isEmpty else {
            return
        }
        update(game.submit(word, words: words))
    }

    func clear() {
        chosen = []
    }

    func shuffle() {
        guard let game else {
            return
        }
        chosen = []
        self.game = game.shuffle(order: Array(0..<game.wheel.count).shuffled())
    }

    func hint() {
        guard let game else {
            return
        }
        update(game.reveal { $0.randomElement() })
    }

    func newPuzzle() async -> Int64 {
        guard let level = saved?.ref.level, let puzzles = try? await WordWheelBank.shared.puzzles(level) else {
            return id
        }
        return store.start(.random(puzzles: puzzles, level: level, seed: Int64.random(in: .min ... .max)))
    }

    func revealSolution() {
        guard let current = game, !current.isSolved, !revealedAll else {
            return
        }
        pause()
        game = current.revealAll()
        revealedAll = true
        chosen = []
        if let snapshot {
            store.reveal(snapshot)
        }
    }

    func onVisible() {
        guard !isSolved, runningSince == nil else {
            return
        }
        runningSince = ProcessInfo.processInfo.systemUptime
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func onHidden() {
        pause()
        persist()
    }

    private var elapsed: Int64 {
        guard let runningSince else {
            return elapsedBase
        }
        return elapsedBase + Int64((ProcessInfo.processInfo.systemUptime - runningSince) * 1000)
    }

    private func tick() {
        elapsedMs = elapsed
    }

    private func pause() {
        elapsedBase = elapsed
        elapsedMs = elapsedBase
        runningSince = nil
        ticker?.cancel()
        ticker = nil
    }

    private func update(_ after: GameState) {
        guard !revealedAll, let before = game else {
            return
        }
        game = after
        if !before.isSolved && after.isSolved {
            pause()
            if let snapshot {
                newBest = store.solve(snapshot)
                resultSaved = true
            }
        } else if after.found != before.found || after.bonus != before.bonus || after.revealed != before.revealed {
            persist()
        }
    }

    private func persist() {
        guard let snapshot, !isSolved else {
            return
        }
        store.save(snapshot)
    }

    private var snapshot: SavedGame? {
        guard let game, var copy = saved else {
            return nil
        }
        copy.found = game.found
        copy.bonus = game.bonus
        copy.revealed = game.revealed
        copy.elapsedMs = elapsed
        return copy
    }
}
