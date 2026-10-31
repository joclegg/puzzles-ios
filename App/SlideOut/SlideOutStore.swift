import Foundation
import PuzzlesCore
import SlideOutEngine
import SwiftData

@Model
final class SlideOutGameRecord {
    @Attribute(.unique) var id: Int64
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var puzzleId: String
    var level: String
    var puzzle: String
    var moves: String
    var moveCount: Int
    var elapsedMs: Int64
    var hints: Int
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init(id: Int64, ref: PuzzleRef, now: Int64) {
        self.id = id
        uuid = UUID().uuidString.lowercased()
        updatedAt = now
        puzzleId = ref.id
        level = ref.level.name
        puzzle = ref.puzzle.encode()
        moves = ""
        moveCount = 0
        elapsedMs = 0
        hints = 0
        status = GameStatus.inProgress.rawValue
        startedAt = now
        finishedAt = nil
    }

    var ref: PuzzleRef? {
        (try? Puzzle.decode(puzzle)).map { PuzzleRef(id: puzzleId, level: Level.named(level), puzzle: $0) }
    }

    var gameStatus: GameStatus {
        GameStatus(rawValue: status) ?? .abandoned
    }

    var title: String {
        ref?.title ?? Level.named(level).label
    }

    var finishedGame: FinishedGame {
        FinishedGame(
            level: Level.named(level),
            status: gameStatus,
            moveCount: moveCount,
            par: ref?.puzzle.par ?? 0,
            elapsedMs: elapsedMs
        )
    }
}

@MainActor
enum SlideOutStore {
    static let container: ModelContainer = makeContainer()

    private static var context: ModelContext {
        container.mainContext
    }

    private static func makeContainer() -> ModelContainer {
        let folder = URL.applicationSupportDirectory.appending(path: "slideout")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let configuration = ModelConfiguration("slideout", url: folder.appending(path: "slideout.store"))
        if let container = try? ModelContainer(for: SlideOutGameRecord.self, configurations: configuration) {
            return container
        }
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            return try ModelContainer(for: SlideOutGameRecord.self, configurations: configuration)
        } catch {
            fatalError("Slide Out store: \(error)")
        }
    }

    static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    static func get(_ id: Int64) -> SlideOutGameRecord? {
        var descriptor = FetchDescriptor<SlideOutGameRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func start(_ ref: PuzzleRef) -> Int64 {
        let now = nowMs()
        let inProgress = GameStatus.inProgress.rawValue
        let open = FetchDescriptor<SlideOutGameRecord>(predicate: #Predicate { $0.status == inProgress })
        for game in (try? context.fetch(open)) ?? [] where game.ref?.slot == ref.slot {
            game.status = GameStatus.abandoned.rawValue
            game.updatedAt = now
        }
        var last = FetchDescriptor<SlideOutGameRecord>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        last.fetchLimit = 1
        let id = ((try? context.fetch(last).first?.id) ?? 0) + 1
        context.insert(SlideOutGameRecord(id: id, ref: ref, now: now))
        try? context.save()
        return id
    }

    static func save(id: Int64, moves: [Move], elapsedMs: Int64, hints: Int) {
        guard let game = get(id), game.gameStatus == .inProgress else {
            return
        }
        write(game, moves: moves, elapsedMs: elapsedMs, hints: hints, status: .inProgress)
    }

    static func reveal(id: Int64, moves: [Move], elapsedMs: Int64, hints: Int) {
        guard let game = get(id) else {
            return
        }
        write(game, moves: moves, elapsedMs: elapsedMs, hints: hints, status: .revealed)
    }

    static func solve(id: Int64, moves: [Move], elapsedMs: Int64, hints: Int) -> Bool {
        guard let game = get(id) else {
            return false
        }
        write(game, moves: moves, elapsedMs: elapsedMs, hints: hints, status: .solved)
        let solved = GameStatus.solved.rawValue
        let level = game.level
        let others = FetchDescriptor<SlideOutGameRecord>(
            predicate: #Predicate { $0.status == solved && $0.level == level && $0.id != id }
        )
        let previous = ((try? context.fetch(others)) ?? []).map(\.elapsedMs).min()
        return isNewBest(elapsedMs: elapsedMs, previousBestMs: previous)
    }

    static func solvedGames() -> [SlideOutGameRecord] {
        let solved = GameStatus.solved.rawValue
        return (try? context.fetch(FetchDescriptor<SlideOutGameRecord>(predicate: #Predicate { $0.status == solved }))) ?? []
    }

    static func inProgress(puzzleId: String) -> Int64? {
        let status = GameStatus.inProgress.rawValue
        let open = FetchDescriptor<SlideOutGameRecord>(predicate: #Predicate { $0.status == status && $0.puzzleId == puzzleId })
        return (try? context.fetch(open))?.first?.id
    }

    static func dailiesLeft(today: CalendarDay) -> [Level] {
        let solved = GameStatus.solved.rawValue
        let finished = FetchDescriptor<SlideOutGameRecord>(predicate: #Predicate { $0.status == solved })
        let ids = Set(((try? context.fetch(finished)) ?? []).map(\.puzzleId))
        return Level.allCases.filter { !ids.contains(PuzzleRef.dailyId(date: today, level: $0)) }
    }

    private static func write(
        _ game: SlideOutGameRecord,
        moves: [Move],
        elapsedMs: Int64,
        hints: Int,
        status: GameStatus
    ) {
        let now = nowMs()
        game.moves = MoveCodec.encode(moves)
        game.moveCount = moves.count
        game.elapsedMs = elapsedMs
        game.hints = hints
        game.status = status.rawValue
        game.updatedAt = now
        if status != .inProgress {
            game.finishedAt = now
        }
        try? context.save()
    }
}

actor SlideOutBank {
    static let shared = SlideOutBank()

    private var loaded: [Level: [Puzzle]] = [:]

    func puzzles(_ level: Level) async throws -> [Puzzle] {
        if let puzzles = loaded[level] {
            return puzzles
        }
        let lines = try await BankStore.shared.lines("slideout/\(level.name.lowercased()).txt")
        let puzzles = try lines.map(Puzzle.decode)
        loaded[level] = puzzles
        return puzzles
    }

    func random(_ level: Level) async throws -> PuzzleRef {
        PuzzleRef.random(puzzles: try await puzzles(level), level: level, seed: Int64.random(in: .min ... .max))
    }

    func daily(_ level: Level, date: CalendarDay) async throws -> PuzzleRef {
        PuzzleRef.daily(puzzles: try await puzzles(level), date: date, level: level)
    }
}

extension CalendarDay {
    static var slideOutToday: CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    var slideOutDayMonth: String {
        let parts = isoString.split(separator: "-").compactMap { Int($0) }
        return dayMonthLabel(month: parts[1], day: parts[2])
    }
}
