import SwiftUI

enum FiveLettersGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(FiveLettersView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
