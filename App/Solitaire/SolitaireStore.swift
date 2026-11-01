import PuzzlesSync
import Foundation
import Observation
import SolitaireEngine
import SwiftData

@Model
final class SolitaireGameRecord {
    @Attribute(.unique) var id: Int64
    @Attribute(.unique) var uuid: String
    var updatedAt: Int64
    var dealId: String
    var drawMode: String
    var buildOrder: String
    var deal: String
    var moves: String
    var moveCount: Int
    var elapsedMs: Int64
    var status: String
    var startedAt: Int64
    var finishedAt: Int64?

    init?(sync fields: SyncFields, id: Int64, uuid: String, updatedAt: Int64) {
        guard let dealId = fields.string("dealId"), let drawMode = fields.enumValue("drawMode"),
            let buildOrder = fields.enumValue("order"), let deal = fields.string("board"), let moves = fields.string("moves"),
            let elapsedMs = fields.long("elapsedMs"), let status = fields.enumValue("status"), let startedAt = fields.long("startedAt")
        else {
            return nil
        }
        self.id = id
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.dealId = dealId
        self.drawMode = drawMode
        self.buildOrder = buildOrder
        self.deal = deal
        self.moves = moves
        moveCount = fields.int("moveCount") ?? 0
        self.elapsedMs = elapsedMs
        self.status = status
        self.startedAt = startedAt
        finishedAt = fields.long("finishedAt")
    }

    var syncJSON: [String: Any] {
        [
            "id": uuid, "dealId": dealId, "drawMode": jsonName(fromEnum: drawMode), "order": jsonName(fromEnum: buildOrder),
            "board": deal, "moves": moves, "moveCount": moveCount, "elapsedMs": elapsedMs, "status": jsonName(fromEnum: status),
            "startedAt": startedAt, "finishedAt": nullable(finishedAt),
        ]
    }

    init(game: SavedGame, updatedAt: Int64) {
        id = game.id
        uuid = UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        dealId = game.deal.id
        drawMode = game.deal.drawMode.storageName
        buildOrder = game.deal.order.storageName
        deal = BoardCodec.encode(game.deal.board)
        moves = MoveCodec.encode(game.moves)
        moveCount = game.moves.count
        elapsedMs = game.elapsedMs
        status = game.status.rawValue
        startedAt = game.startedAt
        finishedAt = game.finishedAt
    }

    var model: SavedGame? {
        guard let mode = DrawMode(storageName: drawMode), let order = BuildOrder(storageName: buildOrder),
            let state = GameStatus(rawValue: status)
        else {
            return nil
        }
        return SavedGame(
            id: id,
            deal: DealRef(id: dealId, drawMode: mode, board: BoardCodec.decode(deal), order: order),
            moves: MoveCodec.decode(moves),
            elapsedMs: elapsedMs,
            status: state,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

@MainActor
@Observable
final class SolitaireStore {
    static let shared = SolitaireStore()

    private(set) var games: [SavedGame] = []
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let now: () -> Int64

    init(now: @escaping () -> Int64 = { GameClock.nowMs() }) {
        self.now = now
        let folder = URL.applicationSupportDirectory.appending(path: "solitaire")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let configuration = ModelConfiguration("solitaire", url: folder.appending(path: "solitaire.store"))
        do {
            let container = try ModelContainer(for: SolitaireGameRecord.self, configurations: configuration)
            context = ModelContext(container)
        } catch {
            fatalError("Solitaire's store did not open: \(error)")
        }
        reload()
    }

    var inProgress: [SavedGame] {
        games.filter { $0.status == .inProgress }
    }

    var savedDeal: SavedGame? {
        inProgress.first { !$0.deal.isDaily }
    }

    func stats() -> [DrawStats] {
        DrawMode.allCases.map { DrawStats(drawMode: $0, games: games) }
    }

    func history(filter: DrawMode?) -> [SavedGame] {
        games.filter { filter == nil || $0.deal.drawMode == filter }
    }

    func dailyWon(_ id: String) -> Bool {
        games.contains { $0.deal.id == id && $0.status == .won }
    }

    func game(id: Int64) -> SavedGame? {
        games.first { $0.id == id }
    }

    func start(_ deal: DealRef) -> SavedGame {
        for var game in inProgress where game.deal.slot == deal.slot {
            game.status = .abandoned
            write(game)
        }
        let game = SavedGame(
            id: (games.map(\.id).max() ?? 0) + 1,
            deal: deal,
            moves: [],
            elapsedMs: 0,
            status: .inProgress,
            startedAt: now(),
            finishedAt: nil
        )
        context.insert(SolitaireGameRecord(game: game, updatedAt: now()))
        commit()
        return game
    }

    func save(_ game: SavedGame) {
        write(game)
        commit()
    }

    func lose(_ game: SavedGame) {
        var lost = game
        lost.status = .lost
        lost.finishedAt = now()
        save(lost)
    }

    func win(_ game: SavedGame) -> Bool {
        var won = game
        won.status = .won
        won.finishedAt = now()
        save(won)
        let previous =
            games
            .filter { $0.status == .won && $0.deal.drawMode == game.deal.drawMode && $0.id != game.id }
            .map(\.elapsedMs)
            .min()
        return isNewBest(elapsedMs: game.elapsedMs, previousBestMs: previous)
    }

    private func write(_ game: SavedGame) {
        let id = game.id
        let descriptor = FetchDescriptor<SolitaireGameRecord>(predicate: #Predicate { $0.id == id })
        guard let record = context.fetchOrEmpty(descriptor).first else {
            return
        }
        record.updatedAt = now()
        record.moves = MoveCodec.encode(game.moves)
        record.moveCount = game.moves.count
        record.elapsedMs = game.elapsedMs
        record.status = game.status.rawValue
        record.finishedAt = game.finishedAt
    }

    private func commit() {
        context.saveOrReport()
        reload()
    }

    private func reload() {
        let descriptor = FetchDescriptor<SolitaireGameRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        games = (context.fetchOrEmpty(descriptor)).compactMap(\.model)
    }
}

enum SolitaireSettingKey {
    static let drawMode = "solitaire_draw_mode"
    static let reverse = "solitaire_reverse"
    static let oneTapMove = "solitaire_one_tap_move"
    static let winnableOnly = "solitaire_winnable_only"
    static let warnUnwinnable = "solitaire_warn_unwinnable"
    static let showTimer = "solitaire_show_timer"
    static let showMoveCount = "solitaire_show_move_count"
    static let showHints = "solitaire_show_hints"
    static let showTutorial = "solitaire_show_tutorial"
    static let hintFill = "solitaire_hint_fill"
}

struct SolitairePreferences {
    let drawMode: DrawMode
    let order: BuildOrder
    let oneTapMove: Bool
    let winnableOnly: Bool
    let warnUnwinnable: Bool
    let hintFill: Bool

    static var current: SolitairePreferences {
        let defaults = UserDefaults.standard
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        return SolitairePreferences(
            drawMode: DrawMode(storageName: defaults.string(forKey: SolitaireSettingKey.drawMode) ?? "") ?? .drawOne,
            order: flag(SolitaireSettingKey.reverse, false) ? .up : .down,
            oneTapMove: flag(SolitaireSettingKey.oneTapMove, true),
            winnableOnly: flag(SolitaireSettingKey.winnableOnly, true),
            warnUnwinnable: flag(SolitaireSettingKey.warnUnwinnable, false),
            hintFill: flag(SolitaireSettingKey.hintFill, false)
        )
    }
}

enum SolitaireDealer {
    static func newSeed() -> Int64 {
        Int64.random(in: Int64.min...Int64.max)
    }

    static func winnableSeeds(drawMode: DrawMode, order: BuildOrder, enabled: Bool) async -> [Int64]? {
        guard enabled,
            let lines = await attempt("Solitaire winnable deals", {
                try await BankStore.shared.lines(WinnableDeals.bankPath(drawMode: drawMode, order: order))
            })
        else {
            return nil
        }
        return WinnableDeals.seeds(lines: lines)
    }
}

extension SolitaireGameRecord: SyncedRecord {
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [SolitaireGameRecord]) -> SolitaireGameRecord? {
        SolitaireGameRecord(sync: fields, id: (existing.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: updatedAt)
    }
}
