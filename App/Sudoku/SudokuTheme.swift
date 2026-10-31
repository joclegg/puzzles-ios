import SudokuEngine
import SwiftUI

struct SudokuPalette {
    let background: Color
    let givenCell: Color
    let doneDigit: Color
    let enteredDigit: Color
    let noteDigit: Color
    let highlightedNote: Color
    let selected: Color
    let sameDigit: Color
    let peer: Color
    let wrong: Color
    let trialMark: Color
    let thinLine: Color
    let thickLine: Color
    let cageLine: Color
    let cageSum: Color
    let accent: Color
    let givenPeer: Color

    static let light = SudokuPalette(
        background: hex(0xFFFFFF), givenCell: hex(0xD5D8DD), doneDigit: hex(0x7A808A, 0.4),
        enteredDigit: hex(0x14181F), noteDigit: hex(0x4A515B), highlightedNote: hex(0x1565D8),
        selected: hex(0x8EC0FA), sameDigit: hex(0xBCD9FC), peer: hex(0xE5F0FE), wrong: hex(0xD32F2F),
        trialMark: hex(0xE53935), thinLine: hex(0xA7AFBB), thickLine: hex(0x263040), cageLine: hex(0x5F6670),
        cageSum: hex(0x262C35), accent: hex(0x1565D8),
        givenPeer: hex(0xDDE4EE))

    static let dark = SudokuPalette(
        background: hex(0x121418), givenCell: hex(0x353A42), doneDigit: hex(0x8C939F, 0.4),
        enteredDigit: hex(0xE9ECF1), noteDigit: hex(0xB8BEC8), highlightedNote: hex(0x7DB5FF),
        selected: hex(0x2F5E99), sameDigit: hex(0x244A78), peer: hex(0x1A2B40), wrong: hex(0xFF6B6B),
        trialMark: hex(0xFF5252), thinLine: hex(0x555E6C), thickLine: hex(0xB4BFCF), cageLine: hex(0xA2A9B4),
        cageSum: hex(0xDDE1E7), accent: hex(0x7DB5FF),
        givenPeer: hex(0x283341))

    private static func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255, opacity: alpha)
    }
}

extension EnvironmentValues {
    var sudokuPalette: SudokuPalette {
        colorScheme == .dark ? .dark : .light
    }
}

struct SudokuBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PuzzleIcon.image("chevron.backward")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

struct SudokuIconButton: View {
    let symbol: String
    let label: String
    let id: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PuzzleIcon.image(symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct SudokuSegments<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let label: (Option) -> String
    let id: (Option) -> String
    let onSelect: (Option) -> Void
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(label(option))
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(option == selected ? palette.peer : Color.clear)
                        .foregroundStyle(palette.enteredDigit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == selected ? .isSelected : [])
                .accessibilityIdentifier(id(option))
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(palette.thinLine))
    }
}

struct SudokuDialog<Content: View>: View {
    let id: String?
    var title: String?
    var bordered = false
    let onDismiss: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                if let title {
                    Text(title).font(.title3.weight(.semibold))
                }
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 24).stroke(palette.accent.opacity(0.3))
                }
            }
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id ?? "")
        }
    }
}

struct SudokuTextButton: View {
    let title: String
    var id: String?
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .accessibilityIdentifier(id ?? title)
    }
}

struct SudokuPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.default, value: configuration.isPressed)
    }
}

struct SudokuTileStyle: ViewModifier {
    var active = false
    var radius: CGFloat = 16
    @Environment(\.sudokuPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(active ? palette.accent.opacity(0.5) : Color.primary.opacity(0.12))
            )
    }
}

struct SudokuScreen<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.enteredDigit)
            .tint(palette.accent)
    }
}
