import SwiftUI

enum SlideOutGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Slide Out"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
