import PuzzlesCore

public enum GameStatus: String, CaseIterable, Sendable {
    case inProgress = "IN_PROGRESS"
    case won = "WON"
    case lost = "LOST"
    case abandoned = "ABANDONED"

    public var label: String {
        switch self {
        case .inProgress:
            "In progress"
        case .won:
            "Won"
        case .lost:
            "Lost"
        case .abandoned:
            "Abandoned"
        }
    }
}

extension DrawMode {
    public var storageName: String {
        switch self {
        case .drawOne:
            "DRAW_ONE"
        case .drawThree:
            "DRAW_THREE"
        }
    }

    public var tagName: String {
        storageName.lowercased()
    }

    public var label: String {
        "Draw \(cards)"
    }

    public var bankName: String {
        switch self {
        case .drawOne:
            "drawOne"
        case .drawThree:
            "drawThree"
        }
    }

    public init?(storageName: String) {
        guard let mode = DrawMode.allCases.first(where: { $0.storageName == storageName }) else {
            return nil
        }
        self = mode
    }
}

extension BuildOrder {
    public var storageName: String {
        switch self {
        case .down:
            "DOWN"
        case .up:
            "UP"
        }
    }

    public init?(storageName: String) {
        guard let order = BuildOrder.allCases.first(where: { $0.storageName == storageName }) else {
            return nil
        }
        self = order
    }
}

public enum WinnableDeals {
    private static let dailySeedLines = 1000

    public static func bankPath(drawMode: DrawMode, order: BuildOrder) -> String {
        "solitaire/\(drawMode.bankName)_\(order.storageName.lowercased()).txt"
    }

    public static func seeds(lines: [String]) -> [Int64] {
        lines.compactMap { Int64($0.trimmingPrefix(while: \.isWhitespace)) }
    }

    public static func random(seed: Int64, seeds: [Int64]) -> Int64 {
        var random = XorWowRandom(seed: seed)
        return seeds[random.nextInt(below: seeds.count)]
    }

    public static func daily(day: CalendarDay, seeds: [Int64]) -> Int64 {
        let count = min(dailySeedLines, seeds.count)
        let index = day.daysSinceEpoch % count
        return seeds[index < 0 ? index + count : index]
    }
}

public struct DealRef: Hashable, Sendable {
    public static let dailyPrefix = "daily_"
    private static let randomSlot = "deal"
    private static let randomPrefix = "deal_"
    private static let dailySeedSpread: Int64 = 7919
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    public let id: String
    public let drawMode: DrawMode
    public let board: Board
    public let order: BuildOrder

    public init(id: String, drawMode: DrawMode, board: Board, order: BuildOrder = .down) {
        self.id = id
        self.drawMode = drawMode
        self.board = board
        self.order = order
    }

    public var isDaily: Bool {
        id.hasPrefix(DealRef.dailyPrefix)
    }

    public var slot: String {
        isDaily ? id : DealRef.randomSlot
    }

    public var title: String {
        let kind = isDaily ? "Daily · \(DealRef.dayLabel(iso: String(id.dropFirst(DealRef.dailyPrefix.count))))" : drawMode.label
        return order == .up ? "\(kind) · Reverse" : kind
    }

    public static func dailyId(_ day: CalendarDay) -> String {
        "\(dailyPrefix)\(day.isoString)"
    }

    public static func dayLabel(iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]), months.indices.contains(month - 1) else {
            return iso
        }
        return "\(day) \(months[month - 1])"
    }

    public static func random(seed: Int64, drawMode: DrawMode, order: BuildOrder = .down, winnableSeeds: [Int64]? = nil) -> DealRef {
        let dealSeed = winnableSeeds.flatMap { $0.isEmpty ? nil : WinnableDeals.random(seed: seed, seeds: $0) } ?? seed
        return DealRef(id: "\(randomPrefix)\(seed)", drawMode: drawMode, board: Board.deal(seed: dealSeed), order: order)
    }

    public static func daily(day: CalendarDay, drawMode: DrawMode, order: BuildOrder = .down, winnableSeeds: [Int64]? = nil) -> DealRef {
        let dealSeed =
            winnableSeeds.flatMap { $0.isEmpty ? nil : WinnableDeals.daily(day: day, seeds: $0) }
            ?? Int64(day.daysSinceEpoch) &* dailySeedSpread
        return DealRef(id: dailyId(day), drawMode: drawMode, board: Board.deal(seed: dealSeed), order: order)
    }
}

public struct SavedGame: Hashable, Sendable, Identifiable {
    public let id: Int64
    public let deal: DealRef
    public var moves: [Move]
    public var elapsedMs: Int64
    public var status: GameStatus
    public let startedAt: Int64
    public var finishedAt: Int64?

    public init(
        id: Int64,
        deal: DealRef,
        moves: [Move],
        elapsedMs: Int64,
        status: GameStatus,
        startedAt: Int64,
        finishedAt: Int64?
    ) {
        self.id = id
        self.deal = deal
        self.moves = moves
        self.elapsedMs = elapsedMs
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var summary: String {
        "\(status.label) · \(moves.count) moves"
    }

    public var continueDetail: String {
        "\(deal.title) · \(formatDuration(elapsedMs)) · \(moves.count) moves"
    }
}

public struct DrawStats: Hashable, Sendable {
    public let drawMode: DrawMode
    public let played: Int
    public let won: Int
    public let bestMs: Int64?
    public let averageMs: Int64?
    public let fewestMoves: Int?

    public init(drawMode: DrawMode, games: [SavedGame]) {
        let finished = games.filter { $0.deal.drawMode == drawMode && $0.status != .inProgress }
        let wins = finished.filter { $0.status == .won }
        self.drawMode = drawMode
        played = finished.count
        won = wins.count
        bestMs = wins.map(\.elapsedMs).min()
        averageMs = wins.isEmpty ? nil : wins.reduce(0) { $0 + $1.elapsedMs } / Int64(wins.count)
        fewestMoves = wins.map(\.moves.count).min()
    }

    public var winRate: String {
        played == 0 ? "–" : "\(won * 100 / played)%"
    }
}

public func isNewBest(elapsedMs: Int64, previousBestMs: Int64?) -> Bool {
    previousBestMs.map { elapsedMs < $0 } ?? true
}

public func hintText(board: Board, selection: Selection, to: Pile) -> String {
    let cards = board.cardsIn(selection.pile)
    let name = cards[cards.count - selection.count].hintLabel
    if case .foundation = to {
        return "Move the \(name) to its foundation."
    }
    let place: String
    if let target = board.cardsIn(to).last {
        place = "onto the \(target.hintLabel)"
    } else if case .tableau(let index) = to {
        place = "to the empty column \(index + 1)"
    } else {
        place = ""
    }
    if case .tableau(let source) = selection.pile {
        let column = board.tableau[source]
        if column.faceUpFrom > 0 && column.cards.count - selection.count == column.faceUpFrom {
            return "Move the \(name) \(place) to turn over the card under it."
        }
        return "Move the \(name) \(place)."
    }
    return "Move the \(name) from the waste \(place), so the card under it can be played."
}

extension Card {
    fileprivate var hintLabel: String {
        "\(rankLabel)\(suit.symbol)"
    }
}

extension GameState {
    public func withMoves(_ moves: [Move]) -> GameState {
        GameState(start: start, drawMode: drawMode, moves: moves, selection: nil, oneTapMove: oneTapMove, order: order)
    }
}
