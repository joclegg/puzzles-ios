import Foundation
import PuzzlesCore
import SudokuEngine
import SwiftData

@MainActor
@Observable
final class SudokuStore {
    static let shared = SudokuStore()

    private static let lowWatermark = 10
    private static let stockTarget = 30

    let context: ModelContext
    private var toppingUp = false
    private(set) var revision = 0

    private init() {
        let folder = URL.applicationSupportDirectory.appending(path: "sudoku")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let schema = Schema([SudokuGameRecord.self, SudokuPastBestRecord.self, SudokuGeneratedRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: folder.appending(path: "sudoku.store"))
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            context = ModelContext(container)
            context.autosaveEnabled = false
        } catch {
            fatalError("Could not open the Sudoku store: \(error)")
        }
    }

    private func records() -> [SudokuGameRecord] {
        _ = revision
        let descriptor = FetchDescriptor<SudokuGameRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func commit() {
        try? context.save()
        revision += 1
    }

    var history: [SudokuSavedGame] {
        records().compactMap(\.saved)
    }

    var inProgress: [SudokuSavedGame] {
        records().filter { $0.status == GameStatus.inProgress.rawValue }.compactMap(\.saved)
    }

    var completedDailies: [(id: String, finishedAt: Int64?)] {
        records().filter { $0.status == GameStatus.completed.rawValue && $0.puzzleId.hasPrefix(PuzzleRef.dailyPrefix) }
            .map { ($0.puzzleId, $0.finishedAt) }
    }

    var bests: [BestTime] {
        let finished = records().filter { $0.status == GameStatus.completed.rawValue && !$0.custom }
            .compactMap { record -> FinishedGame? in
                guard let mode = GameMode(rawValue: record.mode),
                    let difficulty = record.difficulty.flatMap(Difficulty.init(name:))
                else {
                    return nil
                }
                return FinishedGame(mode: mode, difficulty: difficulty, elapsedMs: record.elapsedMs)
            }
        return bestTimes(finished: finished, past: pastBests())
    }

    private func pastBests() -> [FinishedGame] {
        let rows = (try? context.fetch(FetchDescriptor<SudokuPastBestRecord>())) ?? []
        return rows.compactMap { row in
            guard let mode = GameMode(rawValue: row.mode), let difficulty = Difficulty(name: row.difficulty) else {
                return nil
            }
            return FinishedGame(mode: mode, difficulty: difficulty, elapsedMs: row.bestMs)
        }
    }

    func game(_ id: Int) -> SudokuSavedGame? {
        records().first { $0.id == id }?.saved
    }

    func start(_ ref: PuzzleRef, mistakeCheck: MistakeCheck) -> SudokuSavedGame {
        let now = GameClock.nowMs()
        let all = records()
        for record in all where record.status == GameStatus.inProgress.rawValue && record.saved?.ref.slot == ref.slot {
            record.status = GameStatus.abandoned.rawValue
            record.updatedAt = now
        }
        let id = (all.map(\.id).max() ?? 0) + 1
        let game = SudokuSavedGame(
            id: id, ref: ref, values: ref.puzzle.givens, notes: [Int](repeating: 0, count: ref.puzzle.givens.count),
            elapsedMs: 0, mistakes: 0, mistakeCheck: mistakeCheck, status: .inProgress, startedAt: now, finishedAt: nil)
        context.insert(SudokuGameRecord(id: id, game: game, now: now))
        commit()
        return game
    }

    func save(_ game: SudokuSavedGame) {
        records().first { $0.id == game.id }?.apply(game, now: GameClock.nowMs())
        commit()
    }

    func reveal(_ game: SudokuSavedGame) {
        var finished = game
        finished.status = .revealed
        finished.finishedAt = GameClock.nowMs()
        save(finished)
    }

    func complete(_ game: SudokuSavedGame) -> Bool {
        var finished = game
        finished.status = .completed
        finished.finishedAt = GameClock.nowMs()
        save(finished)
        guard let difficulty = game.ref.difficulty, !game.ref.custom else {
            return false
        }
        let earlier = records().filter {
            $0.status == GameStatus.completed.rawValue && !$0.custom && $0.mode == game.ref.mode.rawValue
                && $0.difficulty == difficulty.name && $0.id != game.id
        }.map(\.elapsedMs)
        let past = pastBests().filter { $0.mode == game.ref.mode && $0.difficulty == difficulty }.map(\.elapsedMs)
        guard let previous = (earlier + past).min() else {
            return true
        }
        return game.elapsedMs < previous
    }

    private func lines(_ mode: GameMode, _ difficulty: Difficulty) async throws -> [String] {
        let name = BankPick.fileName(mode: mode, difficulty: difficulty)
        return try await BankStore.shared.lines("sudoku/\(name).txt")
    }

    private func linesOrEmpty(_ mode: GameMode, _ difficulty: Difficulty) async -> [String] {
        (try? await lines(mode, difficulty)) ?? []
    }

    func openDaily(mode: GameMode, difficulty: Difficulty, date: CalendarDay) async throws -> Int? {
        let id = DailyIds.of(mode: mode, difficulty: difficulty, date: date)
        if let existing = inProgress.first(where: { $0.ref.id == id }) {
            return existing.id
        }
        let bank = try await lines(mode, difficulty)
        guard !bank.isEmpty else {
            return nil
        }
        let index = BankPick.dailyIndex(mode: mode, difficulty: difficulty, date: date, size: bank.count)
        guard let puzzle = try? PuzzleCodec.decode(bank[index]) else {
            return nil
        }
        let ref = PuzzleRef(id: id, mode: mode, difficulty: difficulty, puzzle: puzzle)
        return start(ref, mistakeCheck: sudokuModeSettings(mode).mistakeCheck).id
    }

    func openLevel(mode: GameMode, difficulty: Difficulty) async -> Int? {
        let slot = PuzzleRef.levelSlot(mode: mode, difficulty: difficulty)
        if let existing = inProgress.first(where: { $0.ref.slot == slot }) {
            return existing.id
        }
        return await startNew(mode: mode, difficulty: difficulty)
    }

    func startNew(mode: GameMode, difficulty: Difficulty) async -> Int? {
        guard let ref = await nextPuzzle(mode: mode, difficulty: difficulty) else {
            return nil
        }
        let id = start(ref, mistakeCheck: sudokuModeSettings(mode).mistakeCheck).id
        if await stock(mode, difficulty) < Self.lowWatermark {
            topUp()
        }
        return id
    }

    private func nextPuzzle(mode: GameMode, difficulty: Difficulty) async -> PuzzleRef? {
        let bank = await linesOrEmpty(mode, difficulty)
        let unplayed = unplayedIndices(mode, difficulty, count: bank.count)
        if let index = unplayed.randomElement(), let puzzle = try? PuzzleCodec.decode(bank[index]) {
            let id = "\(BankPick.fileName(mode: mode, difficulty: difficulty)):\(index)"
            return PuzzleRef(id: id, mode: mode, difficulty: difficulty, puzzle: puzzle)
        }
        let rows = generated(mode, difficulty)
        if let row = rows.first(where: { !$0.used }), let puzzle = try? PuzzleCodec.decode(row.puzzle) {
            row.used = true
            commit()
            return PuzzleRef(id: generatedId(mode, difficulty, row.id), mode: mode, difficulty: difficulty, puzzle: puzzle)
        }
        guard let fresh = await Self.generate(mode: mode, difficulty: difficulty) else {
            return nil
        }
        let id = insertGenerated(mode, difficulty, fresh, used: true)
        return PuzzleRef(id: generatedId(mode, difficulty, id), mode: mode, difficulty: difficulty, puzzle: fresh)
    }

    private func unplayedIndices(_ mode: GameMode, _ difficulty: Difficulty, count: Int) -> [Int] {
        let played = Set(records().filter { $0.mode == mode.rawValue }.map(\.puzzleId))
        let name = BankPick.fileName(mode: mode, difficulty: difficulty)
        return (0..<count).filter { !played.contains("\(name):\($0)") }
    }

    private func stock(_ mode: GameMode, _ difficulty: Difficulty) async -> Int {
        let bank = await linesOrEmpty(mode, difficulty)
        return unplayedIndices(mode, difficulty, count: bank.count).count
            + generated(mode, difficulty).count { !$0.used }
    }

    private func generated(_ mode: GameMode, _ difficulty: Difficulty) -> [SudokuGeneratedRecord] {
        let modeName = mode.rawValue
        let level = difficulty.name
        let descriptor = FetchDescriptor<SudokuGeneratedRecord>(
            predicate: #Predicate { $0.mode == modeName && $0.difficulty == level },
            sortBy: [SortDescriptor(\.id)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    private func insertGenerated(_ mode: GameMode, _ difficulty: Difficulty, _ puzzle: Puzzle, used: Bool) -> Int {
        let all = (try? context.fetch(FetchDescriptor<SudokuGeneratedRecord>())) ?? []
        let id = (all.map(\.id).max() ?? 0) + 1
        context.insert(
            SudokuGeneratedRecord(
                id: id, mode: mode.rawValue, difficulty: difficulty.name, puzzle: PuzzleCodec.encode(puzzle),
                createdAt: GameClock.nowMs(), used: used))
        commit()
        return id
    }

    private func generatedId(_ mode: GameMode, _ difficulty: Difficulty, _ id: Int) -> String {
        "generated_\(BankPick.fileName(mode: mode, difficulty: difficulty)):\(id)"
    }

    private func topUp() {
        if toppingUp {
            return
        }
        toppingUp = true
        Task {
            for mode in GameMode.allCases {
                for difficulty in mode.levels {
                    while await stock(mode, difficulty) < Self.stockTarget {
                        guard let fresh = await Self.generate(mode: mode, difficulty: difficulty) else {
                            break
                        }
                        insertGenerated(mode, difficulty, fresh, used: false)
                    }
                }
            }
            toppingUp = false
        }
    }

    private nonisolated static func generate(mode: GameMode, difficulty: Difficulty) async -> Puzzle? {
        await Task.detached(priority: .utility) {
            var random = XorWowRandom(seed: Int64.random(in: Int64.min...Int64.max))
            while !Task.isCancelled {
                let made =
                    mode == .killer
                    ? Generator.killer(target: difficulty, random: &random)
                    : Generator.classic(target: difficulty, random: &random)
                if let made {
                    return made.puzzle
                }
            }
            return nil
        }.value
    }
}
