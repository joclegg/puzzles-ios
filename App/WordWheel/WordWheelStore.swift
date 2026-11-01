import PuzzlesSync
import Foundation
import Observation
import PuzzlesCore
import SwiftData
import WordWheelEngine

@Model
final class WordWheelGameEntity {
    var id: Int64
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var puzzleId: String
    var level: String
    var puzzle: String
    var found: String
    var bonus: String
    var revealed: String
    var elapsedMs: Int64
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init?(sync fields: SyncFields, id: Int64, uuid: String, updatedAt: Int64) {
        guard let puzzleId = fields.string("puzzleId"), let size = fields.int("size"), let level = Level(rawValue: size),
            let puzzle = fields.string("puzzle"), let changes = fields.string("changes"), let elapsedMs = fields.long("elapsedMs"),
            let status = fields.enumValue("status"), let startedAt = fields.long("startedAt")
        else {
            return nil
        }
        let parts = changes.split(separator: ";", omittingEmptySubsequences: false).map { $0.split(separator: " ").map(String.init) }
        func part(_ index: Int) -> [String] {
            index < parts.count ? parts[index] : []
        }
        self.id = id
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.puzzleId = puzzleId
        self.level = level.name
        self.puzzle = puzzle
        found = part(0).joined(separator: ",")
        bonus = part(1).joined(separator: ",")
        revealed = part(2).map { $0.replacingOccurrences(of: ",", with: ":") }.joined(separator: ",")
        self.elapsedMs = elapsedMs
        self.status = status
        self.startedAt = startedAt
        finishedAt = fields.long("finishedAt")
    }

    var syncJSON: [String: Any] {
        let progress = [
            found.split(separator: ",").joined(separator: " "),
            bonus.split(separator: ",").joined(separator: " "),
            revealed.split(separator: ",").map { $0.replacingOccurrences(of: ":", with: ",") }.joined(separator: " "),
        ]
        return [
            "id": uuid, "puzzleId": puzzleId, "size": Level.allCases.first { $0.name == level }?.rawValue ?? 0, "puzzle": puzzle,
            "changes": progress.joined(separator: ";"), "hints": revealed.split(separator: ",").count, "mistakes": 0,
            "elapsedMs": elapsedMs, "status": jsonName(fromEnum: status), "startedAt": startedAt, "finishedAt": nullable(finishedAt),
        ]
    }

    init(game: SavedGame, updatedAt: Int64) {
        id = game.id
        uuid = UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        puzzleId = game.ref.id
        level = game.ref.level.name
        puzzle = game.ref.puzzle.encode()
        found = SavedGameCodec.encodeWords(game.found)
        bonus = SavedGameCodec.encodeWords(game.bonus)
        revealed = SavedGameCodec.encodeCells(game.revealed)
        elapsedMs = game.elapsedMs
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = game.finishedAt
    }

    func apply(_ game: SavedGame, updatedAt: Int64) {
        self.updatedAt = updatedAt
        found = SavedGameCodec.encodeWords(game.found)
        bonus = SavedGameCodec.encodeWords(game.bonus)
        revealed = SavedGameCodec.encodeCells(game.revealed)
        elapsedMs = game.elapsedMs
        status = game.status.rawValue
        finishedAt = game.finishedAt
    }

    var model: SavedGame? {
        guard let level = Level.named(level),
            let status = GameStatus(rawValue: status),
            let puzzle = try? Puzzle.decode(puzzle),
            let revealed = try? SavedGameCodec.decodeCells(revealed)
        else {
            return nil
        }
        return SavedGame(
            id: id,
            ref: PuzzleRef(id: puzzleId, level: level, puzzle: puzzle),
            found: SavedGameCodec.decodeWords(found),
            bonus: SavedGameCodec.decodeWords(bonus),
            revealed: revealed,
            elapsedMs: elapsedMs,
            status: status,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

@MainActor
@Observable
final class WordWheelStore {
    static let shared = WordWheelStore()

    private(set) var history: [SavedGame] = []
    @ObservationIgnored private var entities: [WordWheelGameEntity] = []
    @ObservationIgnored let context: ModelContext

    private init() {
        context = ModelContext(Self.makeContainer())
        refresh()
    }

    var inProgress: [SavedGame] {
        history.filter { $0.status == .inProgress }
    }

    var stats: [LevelStats] {
        Level.allCases.map { LevelStats.of(history, level: $0) }
    }

    func game(id: Int64) -> SavedGame? {
        history.first { $0.id == id }
    }

    func dailySolved(on date: CalendarDay) -> Set<Level> {
        Set(
            Level.allCases.filter { level in
                history.contains { $0.ref.id == PuzzleRef.dailyId(date: date, level: level) && $0.status == .solved }
            }
        )
    }

    func start(_ ref: PuzzleRef) -> Int64 {
        let time = now
        for game in inProgress where game.ref.slot == ref.slot {
            var abandoned = game
            abandoned.status = .abandoned
            write(abandoned, time: time)
        }
        let id = (entities.map(\.id).max() ?? 0) + 1
        let game = SavedGame(id: id, ref: ref, startedAt: time)
        context.insert(WordWheelGameEntity(game: game, updatedAt: time))
        commit()
        return id
    }

    func openDaily(_ level: Level, date: CalendarDay = CalendarDay.today) async throws -> Int64 {
        let id = PuzzleRef.dailyId(date: date, level: level)
        if let existing = inProgress.first(where: { $0.ref.id == id }) {
            return existing.id
        }
        let puzzles = try await WordWheelBank.shared.puzzles(level)
        return start(.daily(puzzles: puzzles, date: date, level: level))
    }

    func save(_ game: SavedGame) {
        write(game, time: now)
        commit()
    }

    func reveal(_ game: SavedGame) {
        var finished = game
        finished.status = .revealed
        finished.finishedAt = now
        save(finished)
    }

    func solve(_ game: SavedGame) -> Bool {
        var finished = game
        finished.status = .solved
        finished.finishedAt = now
        save(finished)
        let previous =
            history
            .filter { $0.status == .solved && $0.ref.level == game.ref.level && $0.id != game.id }
            .map(\.elapsedMs)
            .min()
        guard let previous else {
            return true
        }
        return game.elapsedMs < previous
    }

    private var now: Int64 {
        GameClock.nowMs()
    }

    private func write(_ game: SavedGame, time: Int64) {
        entities.first { $0.id == game.id }?.apply(game, updatedAt: time)
    }

    private func commit() {
        try? context.save()
        refresh()
    }

    private func refresh() {
        let descriptor = FetchDescriptor<WordWheelGameEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        entities = (try? context.fetch(descriptor)) ?? []
        history = entities.compactMap(\.model)
    }

    private static func makeContainer() -> ModelContainer {
        let directory = URL.applicationSupportDirectory.appending(path: "word_wheel")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "word_wheel.store")
        let schema = Schema([WordWheelGameEntity.self])
        let configuration = ModelConfiguration("WordWheel", schema: schema, url: url)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Word Wheel store: \(error)")
        }
    }
}

@MainActor
final class WordWheelBank {
    static let shared = WordWheelBank()

    private var loaded: [Level: [Puzzle]] = [:]
    private var list: WordList?

    func puzzles(_ level: Level) async throws -> [Puzzle] {
        if let puzzles = loaded[level] {
            return puzzles
        }
        let lines = try await BankStore.shared.lines("wordwheel/\(level.name.lowercased()).txt")
        let puzzles = try await Task.detached { try lines.map(Puzzle.decode) }.value
        loaded[level] = puzzles
        return puzzles
    }

    func words() async throws -> WordList {
        if let list {
            return list
        }
        let lines = try await BankStore.shared.lines("wordwheel/valid.txt")
        let made = await Task.detached { WordList(valid: lines, common: []) }.value
        list = made
        return made
    }
}

extension WordWheelGameEntity: SyncedRecord {
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [WordWheelGameEntity]) -> WordWheelGameEntity? {
        WordWheelGameEntity(sync: fields, id: (existing.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: updatedAt)
    }
}
