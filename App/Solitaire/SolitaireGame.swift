import PuzzlesCore
import SolitaireEngine
import SwiftData
import SwiftUI

enum SolitaireGame: GameDefinition {
    typealias Record = SolitaireGameRecord

    static let tab = SettingsTab.solitaire
    static let syncKey = "solitaire"

    static var context: ModelContext {
        SolitaireStore.shared.context
    }

    @MainActor
    static let dailies = DailyProvider<Void>(
        tab: .solitaire, group: { _ in "SOLITAIRE" }, options: [()], label: { _ in "Deal" }, tag: { _ in "daily_play_solitaire" },
        calendarLabel: { _ in "Daily deal" },
        results: {
            SolitaireStore.shared.games.filter { $0.status == .won }.compactMap {
                dailyResult(id: $0.deal.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let won = SolitaireStore.shared.dailyWon(DealRef.dailyId(date))
            return { _ in won }
        },
        open: { date, _ in await openDaily(date) }
    )

    @MainActor
    private static func openDaily(_ date: CalendarDay) async -> String? {
        let store = SolitaireStore.shared
        let id = DealRef.dailyId(date)
        if let existing = store.inProgress.first(where: { $0.deal.id == id }) {
            return String(existing.id)
        }
        let prefs = SolitairePreferences.current
        let seeds = await SolitaireDealer.winnableSeeds(drawMode: prefs.drawMode, order: prefs.order, enabled: prefs.winnableOnly)
        let deal = DealRef.daily(day: date, drawMode: prefs.drawMode, order: prefs.order, winnableSeeds: seeds)
        return String(store.start(deal).id)
    }

    @MainActor
    static func home() -> AnyView {
        AnyView(SolitaireHomeView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let deal = SolitaireFixtures.deal(name) else {
                return nil
            }
            return AnyView(SolitaireHomeView(startDeal: deal))
        #else
            return nil
        #endif
    }
}

#if DEBUG
    enum SolitaireFixtures {
        static func deal(_ name: String) -> DealRef? {
            switch name {
            case "simple":
                fixture(name, "5C/AH|/KS|/QH|/|/|/|/;2H3C;;|||")
            case "one_move_to_win":
                fixture(name, "/KS|/|/|/|/|/|/;;;\(foundationsMissingKingOfSpades)")
            default:
                nil
            }
        }

        private static var foundationsMissingKingOfSpades: String {
            Suit.allCases.map { suit in
                Card.deck
                    .filter { $0.suit == suit && (suit != .spades || $0.rank < Card.king) }
                    .map(\.code)
                    .joined()
            }.joined(separator: "|")
        }

        private static func fixture(_ name: String, _ board: String) -> DealRef {
            DealRef(id: "fixture_\(name)", drawMode: .drawOne, board: BoardCodec.decode(board))
        }
    }
#endif
