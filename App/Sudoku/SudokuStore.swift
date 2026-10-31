import Foundation
import PuzzlesCore
import SudokuEngine
import SwiftData

@Model
final class SudokuGameRecord {
    var id: Int
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var puzzleId: String
    var mode: String
    var difficulty: String?
    var custom: Bool
    var puzzle: String
    var cellValues: String
    var notes: String
    var elapsedMs: Int64
    var mistakes: Int
    var mistakeLevel: String
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?
    var undoHistory: String

    init(id: Int, game: SudokuSavedGame, now: Int64) {
        self.id = id
        uuid = UUID().uuidString.lowercased()
        updatedAt = now
        puzzleId = game.ref.id
        mode = game.ref.mode.rawValue
        difficulty = game.ref.difficulty?.name
        custom = game.ref.custom
        puzzle = PuzzleCodec.encode(game.ref.puzzle)
        cellValues = ""
        notes = ""
        elapsedMs = 0
        mistakes = 0
        mistakeLevel = game.mistakeCheck.rawValue
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = nil
        undoHistory = ""
        apply(game, now: now)
    }

    func apply(_ game: SudokuSavedGame, now: Int64) {
        updatedAt = now
        cellValues = game.values.map(String.init).joined()
        notes = game.notes.map(String.init).joined(separator: ",")
        elapsedMs = game.elapsedMs
        mistakes = game.mistakes
        status = game.status.rawValue
        finishedAt = game.finishedAt
        undoHistory = MoveCodec.encode(game.moves)
    }

    var saved: SudokuSavedGame? {
        guard let decoded = try? PuzzleCodec.decode(puzzle), let gameMode = GameMode(rawValue: mode),
            let moves = try? MoveCodec.decode(undoHistory)
        else {
            return nil
        }
        return SudokuSavedGame(
            id: id,
            ref: PuzzleRef(
                id: puzzleId, mode: gameMode, difficulty: difficulty.flatMap(Difficulty.init(name:)), puzzle: decoded,
                custom: custom),
            values: cellValues.compactMap(\.wholeNumberValue),
            notes: notes.split(separator: ",").compactMap { Int($0) },
            elapsedMs: elapsedMs,
            mistakes: mistakes,
            mistakeCheck: MistakeCheck(rawValue: mistakeLevel) ?? .off,
            status: GameStatus(rawValue: status) ?? .abandoned,
            startedAt: startedAt,
            finishedAt: finishedAt,
            moves: moves
        )
    }
}

@Model
final class SudokuPastBestRecord {
    var mode: String
    var difficulty: String
    var bestMs: Int64

    init(mode: String, difficulty: String, bestMs: Int64) {
        self.mode = mode
        self.difficulty = difficulty
        self.bestMs = bestMs
    }
}

@Model
final class SudokuGeneratedRecord {
    var id: Int
    var mode: String
    var difficulty: String
    var puzzle: String
    var createdAt: Int64
    var used: Bool

    init(id: Int, mode: String, difficulty: String, puzzle: String, createdAt: Int64, used: Bool) {
        self.id = id
        self.mode = mode
        self.difficulty = difficulty
        self.puzzle = puzzle
        self.createdAt = createdAt
        self.used = used
    }
}

struct SudokuSavedGame: Identifiable {
    var id: Int
    var ref: PuzzleRef
    var values: [Int]
    var notes: [Int]
    var elapsedMs: Int64
    var mistakes: Int
    var mistakeCheck: MistakeCheck
    var status: GameStatus
    var startedAt: Int64
    var finishedAt: Int64?
    var moves: [Move] = []

    var title: String {
        gameTitle(
            killer: ref.mode == .killer, custom: ref.custom, difficulty: ref.difficulty,
            answerKnown: ref.puzzle.solution != nil)
    }
}

func sudokuToday() -> CalendarDay {
    sudokuDay(Date())
}

func sudokuDay(_ date: Date) -> CalendarDay {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
}

func sudokuDate(_ day: CalendarDay) -> Date {
    let parts = day.isoString.split(separator: "-").compactMap { Int($0) }
    let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
    return Calendar.current.date(from: components) ?? Date()
}

func sudokuNowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

@MainActor
func sudokuModeSettings(_ mode: GameMode) -> ModeSettings {
    let defaults = UserDefaults.standard
    return ModeSettings(
        mode: mode,
        bool: { defaults.object(forKey: $0) as? Bool },
        string: { defaults.string(forKey: $0) }
    )
}

@MainActor
func sudokuInputMode() -> InputMode {
    UserDefaults.standard.string(forKey: SettingKeys.inputMode).flatMap(InputMode.init(rawValue:)) ?? .cellFirst
}

@MainActor
@Observable
final class SudokuStore {
    static let shared = SudokuStore()

    private static let lowWatermark = 10
    private static let stockTarget = 30

    private let context: ModelContext
    private var bankLines: [String: [String]] = [:]
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

    var dailyResults: [CalendarDay: DailyDay] {
        let finishes = records().filter { $0.status == GameStatus.completed.rawValue }.map { record in
            DailyFinish(
                puzzleId: record.puzzleId,
                finishedOn: record.finishedAt.map { sudokuDay(Date(timeIntervalSince1970: Double($0) / 1000)) })
        }
        return dailyDays(completed: finishes)
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
        let now = sudokuNowMs()
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
        records().first { $0.id == game.id }?.apply(game, now: sudokuNowMs())
        commit()
    }

    func reveal(_ game: SudokuSavedGame) {
        var finished = game
        finished.status = .revealed
        finished.finishedAt = sudokuNowMs()
        save(finished)
    }

    func complete(_ game: SudokuSavedGame) -> Bool {
        var finished = game
        finished.status = .completed
        finished.finishedAt = sudokuNowMs()
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

    private func lines(_ mode: GameMode, _ difficulty: Difficulty) async -> [String] {
        let name = BankPick.fileName(mode: mode, difficulty: difficulty)
        if let cached = bankLines[name] {
            return cached
        }
        let loaded = (try? await BankStore.shared.lines("sudoku/\(name).txt")) ?? []
        bankLines[name] = loaded
        return loaded
    }

    func openDaily(mode: GameMode, date: CalendarDay) async -> Int? {
        let id = DailyIds.of(mode: mode, date: date)
        if let existing = inProgress.first(where: { $0.ref.id == id }) {
            return existing.id
        }
        let difficulty = BankPick.dailyLevel(mode: mode, date: date)
        let bank = await lines(mode, difficulty)
        guard !bank.isEmpty else {
            return nil
        }
        let index = BankPick.dailyIndex(mode: mode, date: date, size: bank.count)
        guard let puzzle = try? PuzzleCodec.decode(bank[index]) else {
            return nil
        }
        let ref = PuzzleRef(id: id, mode: mode, difficulty: difficulty, puzzle: puzzle)
        return start(ref, mistakeCheck: sudokuModeSettings(mode).mistakeCheck).id
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
        let bank = await lines(mode, difficulty)
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
        let bank = await lines(mode, difficulty)
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
                createdAt: sudokuNowMs(), used: used))
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
