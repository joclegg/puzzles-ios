import SwiftUI

enum SudokuGame {
    @MainActor
    static func home() -> AnyView {
        AnyView(Text("Sudoku"))
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        nil
    }
}
