import PuzzlesSync
import Foundation
import KakuroEngine
import PuzzlesCore
import SwiftData

@Model
final class KakuroGameEntity {
    @Attribute(.unique) var id: Int64
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var puzzleId: String
    var size: Int
    var puzzle: String
    var changes: String
    var elapsedMs: Int64
    var hints: Int
    var mistakes: Int
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init?(sync fields: SyncFields, id: Int64, uuid: String, updatedAt: Int64) {
        guard let puzzleId = fields.string("puzzleId"), let size = fields.int("size"), let puzzle = fields.string("puzzle"),
            let changes = fields.string("changes"), let elapsedMs = fields.long("elapsedMs"),
            let status = fields.enumValue("status"), let startedAt = fields.long("startedAt")
        else {
            return nil
        }
        self.id = id
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.puzzleId = puzzleId
        self.size = size
        self.puzzle = puzzle
        self.changes = changes
        self.elapsedMs = elapsedMs
        hints = fields.int("hints") ?? 0
        mistakes = fields.int("mistakes") ?? 0
        self.status = status
        self.startedAt = startedAt
        finishedAt = fields.long("finishedAt")
    }

    var syncJSON: [String: Any] {
        [
            "id": uuid, "puzzleId": puzzleId, "size": size, "puzzle": puzzle, "changes": changes, "hints": hints,
            "mistakes": mistakes, "elapsedMs": elapsedMs, "status": jsonName(fromEnum: status), "startedAt": startedAt,
            "finishedAt": nullable(finishedAt),
        ]
    }

    init(game: SavedGame, updatedAt: Int64) {
        id = game.id
        uuid = UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        puzzleId = game.ref.id
        size = game.ref.size
        puzzle = game.ref.puzzle.encode()
        changes = ChangeCodec.encode(game.changes)
        elapsedMs = game.elapsedMs
        hints = game.hints
        mistakes = game.mistakes
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = game.finishedAt
    }

    func update(from game: SavedGame, updatedAt: Int64) {
        self.updatedAt = updatedAt
        changes = ChangeCodec.encode(game.changes)
        elapsedMs = game.elapsedMs
        hints = game.hints
        mistakes = game.mistakes
        status = game.status.rawValue
        finishedAt = game.finishedAt
    }

    var model: SavedGame? {
        guard let decoded = Puzzle.decode(puzzle),
            let moves = ChangeCodec.decode(changes),
            let state = GameStatus(rawValue: status)
        else {
            return nil
        }
        return SavedGame(
            id: id,
            ref: PuzzleRef(id: puzzleId, puzzle: decoded),
            changes: moves,
            elapsedMs: elapsedMs,
            hints: hints,
            mistakes: mistakes,
            status: state,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

@MainActor
@Observable
final class KakuroStore {
    static let shared = KakuroStore()

    private(set) var games: [SavedGame] = []
    let context: ModelContext

    private init() {
        context = ModelContext(Self.makeContainer())
        reload()
    }

    var inProgress: [SavedGame] {
        games.filter { $0.status == .inProgress }
    }

    func stats() -> [SizeStats] {
        sizes.map { SizeStats.of(size: $0, games: games) }
    }

    func game(id: Int64) -> SavedGame? {
        games.first { $0.id == id }
    }

    func start(ref: PuzzleRef) -> SavedGame {
        let now = Self.nowMs()
        for game in inProgress where game.ref.slot == ref.slot {
            var abandoned = game
            abandoned.status = .abandoned
            write(abandoned, now: now)
        }
        let nextId = (games.map(\.id).max() ?? 0) + 1
        let game = SavedGame(id: nextId, ref: ref, startedAt: now)
        context.insert(KakuroGameEntity(game: game, updatedAt: now))
        commit()
        reload()
        return game
    }

    func save(_ game: SavedGame) {
        write(game, now: Self.nowMs())
        commit()
        reload()
    }

    func reveal(_ game: SavedGame) {
        var finished = game
        finished.status = .revealed
        finished.finishedAt = Self.nowMs()
        save(finished)
    }

    func solve(_ game: SavedGame) -> Bool {
        var finished = game
        finished.status = .solved
        finished.finishedAt = Self.nowMs()
        save(finished)
        let previous =
            games
            .filter { $0.status == .solved && $0.ref.size == game.ref.size && $0.id != game.id }
            .map(\.elapsedMs)
            .min()
        guard let previous else {
            return true
        }
        return game.elapsedMs < previous
    }

    static func nowMs() -> Int64 {
        GameClock.nowMs()
    }

    private func write(_ game: SavedGame, now: Int64) {
        let id = game.id
        let descriptor = FetchDescriptor<KakuroGameEntity>(predicate: #Predicate { $0.id == id })
        context.fetchOrEmpty(descriptor).first?.update(from: game, updatedAt: now)
    }

    private func commit() {
        context.saveOrReport()
    }

    private func reload() {
        let descriptor = FetchDescriptor<KakuroGameEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        games = (context.fetchOrEmpty(descriptor)).compactMap(\.model)
    }

    private static func makeContainer() -> ModelContainer {
        let directory = URL.applicationSupportDirectory.appending(path: "kakuro")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "kakuro.store")
        let schema = Schema([KakuroGameEntity.self])
        let configuration = ModelConfiguration("kakuro", schema: schema, url: url)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Kakuro store: \(error)")
        }
    }
}

@MainActor
enum KakuroBank {
    private static var loaded: [Int: [Puzzle]] = [:]

    static func puzzles(size: Int) async throws -> [Puzzle] {
        if let cached = loaded[size] {
            return cached
        }
        let lines = try await BankStore.shared.lines("kakuro/\(size).txt")
        let puzzles = lines.compactMap(Puzzle.decode)
        loaded[size] = puzzles
        return puzzles
    }
}


extension KakuroGameEntity: SyncedRecord {
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [KakuroGameEntity]) -> KakuroGameEntity? {
        KakuroGameEntity(sync: fields, id: (existing.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: updatedAt)
    }
}
