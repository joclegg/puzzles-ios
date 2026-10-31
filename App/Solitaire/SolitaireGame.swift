import SwiftUI

enum SolitaireGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Solitaire"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
