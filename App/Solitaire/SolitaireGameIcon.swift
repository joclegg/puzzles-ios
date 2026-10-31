import SolitaireEngine
import SwiftUI

struct SolitaireGameIcon: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SolitaireCardFace(card: Card(rank: Card.king, suit: .spades), width: 34, selected: false)
                .frame(width: 34, height: 48)
                .offset(x: 2, y: 2)
            SolitaireCardFace(card: Card(rank: Card.ace, suit: .hearts), width: 34, selected: false)
                .frame(width: 34, height: 48)
                .offset(x: 20, y: 6)
        }
        .frame(width: 56, height: 56)
        .scaleEffect(0.8)
        .accessibilityHidden(true)
    }
}
