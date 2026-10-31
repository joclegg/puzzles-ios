import FiveLettersEngine
import SwiftUI

struct FiveLettersTheme: DynamicProperty {
    @AppStorage(FiveLettersSetting.highContrast.key) private var highContrast = FiveLettersSetting.highContrast.defaultValue
    @Environment(\.colorScheme) private var scheme

    private var dark: Bool {
        scheme == .dark
    }

    var correct: Color {
        highContrast ? Color(hex: 0xE5793A) : Color(hex: dark ? 0x538D4E : 0x5FA463)
    }
    var present: Color {
        highContrast ? Color(hex: 0x6CB7E8) : Color(hex: dark ? 0xB59F3B : 0xD7B23E)
    }
    var absent: Color {
        Color(hex: dark ? 0x3A3F47 : 0x7A808A)
    }
    var markedText: Color {
        .white
    }
    var emptyBorder: Color {
        Color(hex: dark ? 0x3A3F47 : 0xD5D8DD)
    }
    var typedBorder: Color {
        Color(hex: 0x7A808A)
    }
    var text: Color {
        Color(hex: dark ? 0xE9ECF1 : 0x14181F)
    }
    var key: Color {
        Color(hex: dark ? 0x555E6C : 0xE2E5EA)
    }
    var keyText: Color {
        text
    }
    var accent: Color {
        Color(hex: dark ? 0x72BF6D : 0x4F9A53)
    }

    func colour(_ mark: Mark) -> Color {
        switch mark {
        case .correct:
            correct
        case .present:
            present
        case .absent:
            absent
        }
    }
}

extension View {
    func fiveLettersHeader(_ title: String) -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
