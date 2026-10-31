import Foundation
import PuzzlesCore
import SightlinesEngine
import SwiftData

@Model
final class SightlinesGameRecord {
    @Attribute(.unique) var id: Int64
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var puzzleId: String
    var size: Int
    var puzzle: String
    var changes: String
    var elapsedMs: Int64
    var hints: Int
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init(game: SavedGame, uuid: String, updatedAt: Int64) {
        id = game.id
        self.uuid = uuid
        self.updatedAt = updatedAt
        puzzleId = game.ref.id
        size = game.ref.size
        puzzle = game.ref.puzzle.encode()
        changes = ChangeCodec.encode(game.changes)
        elapsedMs = game.elapsedMs
        hints = game.hints
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = game.finishedAt
    }

    func apply(_ game: SavedGame, updatedAt: Int64) {
        self.updatedAt = updatedAt
        changes = ChangeCodec.encode(game.changes)
        elapsedMs = game.elapsedMs
        hints = game.hints
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
            status: state,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

@MainActor
@Observable
final class SightlinesStore {
    static let shared = SightlinesStore()

    private(set) var games: [SavedGame] = []
    private let context: ModelContext

    private init() {
        let folder = URL.applicationSupportDirectory.appending(path: "sightlines")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: folder.appending(path: "sightlines.store"))
            let container = try ModelContainer(for: SightlinesGameRecord.self, configurations: configuration)
            context = ModelContext(container)
        } catch {
            fatalError("Couldn't open the Sightlines store: \(error)")
        }
        reload()
    }

    private static var nowMs: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func game(id: Int64) -> SavedGame? {
        games.first { $0.id == id }
    }

    func start(_ makeRef: @escaping @Sendable () -> PuzzleRef) async -> Int64 {
        let ref = await Task.detached(priority: .userInitiated, operation: makeRef).value
        for var game in games.inProgress where game.ref.slot == ref.slot {
            game.status = .abandoned
            write(game)
        }
        let records = (try? context.fetch(FetchDescriptor<SightlinesGameRecord>())) ?? []
        let id = (records.map(\.id).max() ?? 0) + 1
        let now = Self.nowMs
        let game = SavedGame(id: id, ref: ref, startedAt: now)
        context.insert(SightlinesGameRecord(game: game, uuid: UUID().uuidString.lowercased(), updatedAt: now))
        commit()
        return id
    }

    func save(_ game: SavedGame) {
        write(game)
        commit()
    }

    func reveal(_ game: SavedGame) {
        var finished = game
        finished.status = .revealed
        finished.finishedAt = Self.nowMs
        save(finished)
    }

    func solve(_ game: SavedGame) -> Bool {
        var finished = game
        finished.status = .solved
        finished.finishedAt = Self.nowMs
        save(finished)
        return games.isNewBest(finished)
    }

    private func write(_ game: SavedGame) {
        let id = game.id
        let descriptor = FetchDescriptor<SightlinesGameRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(descriptor).first else {
            return
        }
        record.apply(game, updatedAt: Self.nowMs)
    }

    private func commit() {
        try? context.save()
        reload()
    }

    private func reload() {
        let order = [SortDescriptor(\SightlinesGameRecord.startedAt, order: .reverse), SortDescriptor(\SightlinesGameRecord.id, order: .reverse)]
        let records = (try? context.fetch(FetchDescriptor<SightlinesGameRecord>(sortBy: order))) ?? []
        games = records.compactMap(\.model)
    }
}

enum SightlinesToday {
    static var date: CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}
