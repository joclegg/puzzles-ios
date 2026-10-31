import SolitaireEngine
import SwiftUI

enum SolitaireGame {
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
