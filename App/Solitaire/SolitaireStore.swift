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
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let now: () -> Int64

    init(now: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }) {
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
        guard let record = try? context.fetch(descriptor).first else {
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
        try? context.save()
        reload()
    }

    private func reload() {
        let descriptor = FetchDescriptor<SolitaireGameRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse), SortDescriptor(\.id, order: .reverse)]
        )
        games = ((try? context.fetch(descriptor)) ?? []).compactMap(\.model)
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
            warnUnwinnable: flag(SolitaireSettingKey.warnUnwinnable, true),
            hintFill: flag(SolitaireSettingKey.hintFill, false)
        )
    }
}

enum SolitaireDealer {
    static func newSeed() -> Int64 {
        Int64.random(in: Int64.min...Int64.max)
    }

    static func winnableSeeds(drawMode: DrawMode, order: BuildOrder, enabled: Bool) async -> [Int64]? {
        guard enabled, let lines = try? await BankStore.shared.lines(WinnableDeals.bankPath(drawMode: drawMode, order: order)) else {
            return nil
        }
        return WinnableDeals.seeds(lines: lines)
    }
}
