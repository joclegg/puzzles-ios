import SwiftUI

enum SightlinesGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Sightlines"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
