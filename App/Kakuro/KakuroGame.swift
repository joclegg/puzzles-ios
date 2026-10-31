import SwiftUI

enum KakuroGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Kakuro"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
