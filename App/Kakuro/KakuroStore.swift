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
    private let context: ModelContext

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
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func write(_ game: SavedGame, now: Int64) {
        let id = game.id
        let descriptor = FetchDescriptor<KakuroGameEntity>(predicate: #Predicate { $0.id == id })
        try? context.fetch(descriptor).first?.update(from: game, updatedAt: now)
    }

    private func commit() {
        try? context.save()
    }

    private func reload() {
        let descriptor = FetchDescriptor<KakuroGameEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        games = ((try? context.fetch(descriptor)) ?? []).compactMap(\.model)
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

    static func puzzles(size: Int) async -> [Puzzle] {
        if let cached = loaded[size] {
            return cached
        }
        let lines = (try? await BankStore.shared.lines("kakuro/\(size).txt")) ?? []
        let puzzles = lines.compactMap(Puzzle.decode)
        loaded[size] = puzzles
        return puzzles
    }
}

extension CalendarDay {
    static var today: CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}
