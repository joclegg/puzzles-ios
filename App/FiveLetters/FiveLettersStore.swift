import PuzzlesSync
import FiveLettersEngine
import Foundation
import Observation
import SwiftData

@Model
final class FiveLettersGameRecord {
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var wordId: String
    var answer: String
    var guesses: String
    var hardMode: Bool
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init?(sync fields: SyncFields, uuid: String, updatedAt: Int64) {
        guard let wordId = fields.string("wordId"), let answer = fields.string("answer"),
            let guesses = fields.json["guesses"] as? [String], let status = fields.enumValue("status"),
            let startedAt = fields.long("startedAt")
        else {
            return nil
        }
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.wordId = wordId
        self.answer = answer
        self.guesses = guesses.joined(separator: ",")
        hardMode = fields.bool("hardMode")
        self.status = status
        self.startedAt = startedAt
        finishedAt = fields.long("finishedAt")
    }

    var syncJSON: [String: Any] {
        [
            "id": uuid, "wordId": wordId, "answer": answer, "guesses": guesses.split(separator: ",").map(String.init),
            "hardMode": hardMode, "status": jsonName(fromEnum: status), "startedAt": startedAt, "finishedAt": nullable(finishedAt),
        ]
    }

    init(game: SavedGame, updatedAt: Int64) {
        uuid = game.uuid
        self.updatedAt = updatedAt
        wordId = game.ref.id
        answer = game.ref.answer
        guesses = encodeGuesses(game.guesses)
        hardMode = game.hardMode
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = game.finishedAt
    }

    var game: SavedGame {
        SavedGame(
            uuid: uuid,
            ref: WordRef(id: wordId, answer: answer),
            guesses: decodeGuesses(guesses),
            hardMode: hardMode,
            status: GameStatus(rawValue: status) ?? .abandoned,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    func apply(_ game: SavedGame, updatedAt: Int64) {
        self.updatedAt = updatedAt
        guesses = encodeGuesses(game.guesses)
        status = game.status.rawValue
        finishedAt = game.finishedAt
    }
}

@MainActor
@Observable
final class FiveLettersStore {
    static let shared = FiveLettersStore()

    private(set) var history: [SavedGame] = []

    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private var loadedWords: Words?

    private init() {
        let folder = URL.applicationSupportDirectory.appending(path: "FiveLetters")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: folder.appending(path: "games.store"))
            let container = try ModelContainer(for: FiveLettersGameRecord.self, configurations: configuration)
            context = ModelContext(container)
        } catch {
            fatalError("Five Letters store: \(error)")
        }
        refresh()
    }

    var inProgress: [SavedGame] {
        history.filter { $0.status == .inProgress }
    }

    var practice: SavedGame? {
        inProgress.first { !$0.ref.isDaily && !$0.ref.isDaily2 }
    }

    var stats: WordStats {
        WordStats(history: history)
    }

    func existing(wordId: String) -> SavedGame? {
        history.first { $0.ref.id == wordId && $0.status != .abandoned }
    }

    func game(uuid: String) -> SavedGame? {
        history.first { $0.uuid == uuid }
    }

    func words() async throws -> Words {
        if let loadedWords {
            return loadedWords
        }
        let answers = try await BankStore.shared.lines("words/answers.txt")
        let guesses = try await BankStore.shared.lines("words/guesses.txt")
        let words = Words(answers: answers, guesses: guesses)
        loadedWords = words
        return words
    }

    func start(ref: WordRef, hardMode: Bool) -> SavedGame {
        for game in inProgress where game.ref.slot == ref.slot {
            var abandoned = game
            abandoned.status = .abandoned
            write(abandoned)
        }
        let game = SavedGame(uuid: UUID().uuidString, ref: ref, hardMode: hardMode, startedAt: Self.now())
        context.insert(FiveLettersGameRecord(game: game, updatedAt: Self.now()))
        commit()
        return game
    }

    func save(_ game: SavedGame) {
        write(game)
        commit()
    }

    func finish(_ game: SavedGame, won: Bool) {
        var ended = game
        ended.status = won ? .won : .lost
        ended.finishedAt = Self.now()
        save(ended)
    }

    private func write(_ game: SavedGame) {
        let uuid = game.uuid
        let descriptor = FetchDescriptor<FiveLettersGameRecord>(predicate: #Predicate { $0.uuid == uuid })
        if let record = context.fetchOrEmpty(descriptor).first {
            record.apply(game, updatedAt: Self.now())
        }
    }

    private func commit() {
        context.saveOrReport()
        refresh()
    }

    private func refresh() {
        let descriptor = FetchDescriptor<FiveLettersGameRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        history = (context.fetchOrEmpty(descriptor)).map(\.game)
    }

    private static func now() -> Int64 {
        Int64(Date.now.timeIntervalSince1970 * 1000)
    }
}

enum FiveLettersDaily2 {
    static func word(date: String) async -> String? {
        guard let url = URL(string: "https://puzzles-daily.joclegg.dev/word/\(date)") else {
            return nil
        }
        let request = URLRequest(url: url, timeoutInterval: 5)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200
        else {
            return nil
        }
        return daily2Word(json: String(decoding: data, as: UTF8.self))
    }
}

extension FiveLettersGameRecord: SyncedRecord {
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [FiveLettersGameRecord]) -> FiveLettersGameRecord?
    {
        FiveLettersGameRecord(sync: fields, uuid: uuid, updatedAt: updatedAt)
    }
}
