import Foundation
import Observation
import PuzzlesCore
import SwiftData
import TwoToneEngine

@Model
final class TwoToneGameRecord {
    @Attribute(.unique) var uuid: String
    var id: Int64
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

    init(id: Int64, ref: PuzzleRef, now: Int64) {
        uuid = UUID().uuidString
        self.id = id
        updatedAt = now
        puzzleId = ref.id
        size = ref.size
        puzzle = ref.puzzle.encode()
        changes = ""
        elapsedMs = 0
        hints = 0
        status = GameStatus.inProgress.rawValue
        startedAt = now
        finishedAt = nil
    }

    var gameStatus: GameStatus {
        GameStatus(rawValue: status) ?? .abandoned
    }

    var title: String {
        PuzzleRef.title(id: puzzleId, size: size)
    }

    var ref: PuzzleRef? {
        Puzzle.decode(puzzle).map { PuzzleRef(id: puzzleId, puzzle: $0) }
    }
}

@MainActor
@Observable
final class TwoToneStore {
    static let shared = TwoToneStore()

    private let context: ModelContext
    private(set) var revision = 0

    private init() {
        let folder = URL.applicationSupportDirectory.appending(path: "TwoTone")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: folder.appending(path: "two_tone.store"))
        do {
            let container = try ModelContainer(for: TwoToneGameRecord.self, configurations: configuration)
            context = ModelContext(container)
        } catch {
            preconditionFailure("The Two Tone store could not be opened: \(error)")
        }
    }

    static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    static func today() -> CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    var history: [TwoToneGameRecord] {
        _ = revision
        let order = [SortDescriptor(\TwoToneGameRecord.startedAt, order: .reverse), SortDescriptor(\TwoToneGameRecord.id, order: .reverse)]
        return (try? context.fetch(FetchDescriptor(sortBy: order))) ?? []
    }

    var inProgress: [TwoToneGameRecord] {
        history.filter { $0.gameStatus == .inProgress }
    }

    var stats: [SizeStats] {
        let games = history.map { (size: $0.size, status: $0.gameStatus, elapsedMs: $0.elapsedMs) }
        return sizes.map { SizeStats.of(size: $0, games: games) }
    }

    func dailySolved(date: CalendarDay) -> Set<Int> {
        let games = history
        return Set(
            sizes.filter { size in
                let id = PuzzleRef.dailyId(date: date, size: size)
                return games.contains { $0.puzzleId == id && $0.gameStatus == .solved }
            })
    }

    func game(id: Int64) -> TwoToneGameRecord? {
        history.first { $0.id == id }
    }

    func start(_ makeRef: @escaping @Sendable () -> PuzzleRef) async -> Int64 {
        let ref = await Task.detached(operation: makeRef).value
        return insert(ref)
    }

    func openDaily(date: CalendarDay, size: Int) async -> Int64 {
        let id = PuzzleRef.dailyId(date: date, size: size)
        if let existing = inProgress.first(where: { $0.puzzleId == id }) {
            return existing.id
        }
        return await start { PuzzleRef.daily(date: date, size: size) }
    }

    func replay(_ record: TwoToneGameRecord) -> Int64? {
        record.ref.map(insert)
    }

    func save(_ record: TwoToneGameRecord, changes: [Change], hints: Int, elapsedMs: Int64) {
        record.changes = ChangeCodec.encode(changes)
        record.hints = hints
        record.elapsedMs = elapsedMs
        record.updatedAt = Self.nowMs()
        commit()
    }

    func finish(_ record: TwoToneGameRecord, status: GameStatus) {
        let now = Self.nowMs()
        record.status = status.rawValue
        record.finishedAt = now
        record.updatedAt = now
        commit()
    }

    func isNewBest(_ record: TwoToneGameRecord) -> Bool {
        let previous = history.filter { $0.gameStatus == .solved && $0.size == record.size && $0.id != record.id }.map(\.elapsedMs).min()
        guard let previous else {
            return true
        }
        return record.elapsedMs < previous
    }

    private func insert(_ ref: PuzzleRef) -> Int64 {
        let games = history
        let now = Self.nowMs()
        for game in games where game.gameStatus == .inProgress && PuzzleRef.slot(id: game.puzzleId, size: game.size) == ref.slot {
            game.status = GameStatus.abandoned.rawValue
            game.updatedAt = now
        }
        let id = (games.map(\.id).max() ?? 0) + 1
        context.insert(TwoToneGameRecord(id: id, ref: ref, now: now))
        commit()
        return id
    }

    private func commit() {
        try? context.save()
        revision += 1
    }
}
