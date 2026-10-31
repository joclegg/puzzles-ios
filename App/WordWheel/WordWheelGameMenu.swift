import SwiftUI

struct WordWheelGameMenu: View, Equatable {
    let canReveal: Bool
    let onReveal: () -> Void
    let onSettings: () -> Void

    nonisolated static func == (lhs: WordWheelGameMenu, rhs: WordWheelGameMenu) -> Bool {
        lhs.canReveal == rhs.canReveal
    }

    var body: some View {
        Menu {
            if canReveal {
                Button("Show solution", action: onReveal)
                    .accessibilityIdentifier("menu_solution")
            }
            Button("Settings", action: onSettings)
                .accessibilityIdentifier("menu_settings")
        } label: {
            PuzzleIcon.image("ellipsis")
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }
}
