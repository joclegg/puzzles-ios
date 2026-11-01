import SwiftUI

struct GameMenuItem {
    let title: String
    let id: String
    var disabled = false
    let action: () -> Void
}

struct GameMenu: View, Equatable {
    let key: AnyHashable
    let items: [GameMenuItem]
    let width: CGFloat
    let height: CGFloat
    let tinted: Bool
    private let signature: [String]

    init(key: AnyHashable, items: [GameMenuItem], width: CGFloat = 40, height: CGFloat = 40, tinted: Bool = false) {
        self.key = key
        self.items = items
        self.width = width
        self.height = height
        self.tinted = tinted
        signature = items.map { "\($0.id) \($0.disabled)" }
    }

    nonisolated static func == (lhs: GameMenu, rhs: GameMenu) -> Bool {
        lhs.key == rhs.key && lhs.width == rhs.width && lhs.height == rhs.height && lhs.tinted == rhs.tinted
            && lhs.signature == rhs.signature
    }

    var body: some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button(item.title, action: item.action)
                    .disabled(item.disabled)
                    .accessibilityIdentifier(item.id)
            }
        } label: {
            PuzzleIcon.image("ellipsis")
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .tint(tinted ? Color.primary : nil)
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }
}
