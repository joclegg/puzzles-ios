import SolitaireEngine
import SwiftUI

struct SolitaireGameIcon: View {
    var body: some View {
        ZStack {
            SolitaireCardFace(card: Card(rank: Card.king, suit: .spades), width: 34, selected: false)
                .frame(width: 34, height: 48)
                .offset(x: -9, y: -2)
            SolitaireCardFace(card: Card(rank: Card.ace, suit: .hearts), width: 34, selected: false)
                .frame(width: 34, height: 48)
                .offset(x: 9, y: 2)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}
