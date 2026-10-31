import FiveLettersEngine
import SwiftUI

enum FiveLettersGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(FiveLettersHomeView())
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            switch name {
            case "five_letters_crane":
                return AnyView(FiveLettersHomeView(fixture: WordRef(id: "practice_fixture", answer: "CRANE")))
            default:
                return nil
            }
        #else
            return nil
        #endif
    }
}
