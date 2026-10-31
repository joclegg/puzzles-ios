import SlideOutEngine
import SwiftUI

enum SlideOutGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(SlideOutHomeScreen().modelContainer(SlideOutStore.container))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = SlideOutFixtures.puzzle(name) else {
                return nil
            }
            return AnyView(SlideOutHomeScreen(fixture: ref).modelContainer(SlideOutStore.container))
        #else
            return nil
        #endif
    }
}
