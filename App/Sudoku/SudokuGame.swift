import SudokuEngine
import SwiftUI

enum SudokuGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(SudokuRootView(fixture: nil))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard SudokuFixtures.names.contains(name) else {
                return nil
            }
            return AnyView(SudokuRootView(fixture: name))
        #else
            return nil
        #endif
    }
}
