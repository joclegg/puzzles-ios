import SwiftUI

enum WordWheelGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Word Wheel"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
