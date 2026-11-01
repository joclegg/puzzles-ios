import Foundation
import PuzzlesCore
import PuzzlesSync
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

    init?(sync fields: SyncFields, id: Int, uuid: String, updatedAt: Int64) {
        guard let puzzleId = fields.string("puzzleId"), let mode = fields.enumValue("mode"), let puzzle = fields.string("puzzle"),
            let cellValues = fields.string("values"), let notes = fields.json["notes"] as? [NSNumber],
            let elapsedMs = fields.long("elapsedMs"), let mistakeLevel = fields.enumValue("mistakeCheck"),
            let status = fields.enumValue("status"), let startedAt = fields.long("startedAt")
        else {
            return nil
        }
        self.id = id
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.puzzleId = puzzleId
        self.mode = mode
        difficulty = fields.enumValue("difficulty")
        custom = fields.bool("custom")
        self.puzzle = puzzle
        self.cellValues = cellValues
        self.notes = notes.map { String($0.intValue) }.joined(separator: ",")
        self.elapsedMs = elapsedMs
        mistakes = fields.int("mistakes") ?? 0
        self.mistakeLevel = mistakeLevel
        self.status = status
        self.startedAt = startedAt
        finishedAt = fields.long("finishedAt")
        undoHistory = fields.string("moves") ?? ""
    }

    var syncJSON: [String: Any] {
        [
            "id": uuid, "puzzleId": puzzleId, "mode": jsonName(fromEnum: mode),
            "difficulty": difficulty.map { jsonName(fromEnum: $0) as Any } ?? NSNull(), "custom": custom, "puzzle": puzzle,
            "values": cellValues, "notes": notes.split(separator: ",").compactMap { Int($0) }, "moves": undoHistory,
            "mistakes": mistakes, "mistakeCheck": jsonName(fromEnum: mistakeLevel), "elapsedMs": elapsedMs,
            "status": jsonName(fromEnum: status), "startedAt": startedAt, "finishedAt": nullable(finishedAt),
        ]
    }

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

extension SudokuGameRecord: SyncedRecord {
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [SudokuGameRecord]) -> SudokuGameRecord? {
        SudokuGameRecord(sync: fields, id: (existing.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: updatedAt)
    }
}
