import SwiftUI

enum TwoToneGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Two Tone"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
