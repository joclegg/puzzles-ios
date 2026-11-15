import SwiftUI

struct CrosswordColors {
    let background: Color
    let blockMark: Color
    let line: Color
    let letter: Color
    let number: Color
    let selected: Color
    let word: Color
    let wrong: Color
    let accent: Color

    static let light = CrosswordColors(
        background: Color(hex: 0xFFFFFF),
        blockMark: Color(hex: 0x1E2630),
        line: Color(hex: 0x8C96A3),
        letter: Color(hex: 0x14181F),
        number: Color(hex: 0x4A515B),
        selected: Color(hex: 0x8FCBE0),
        word: Color(hex: 0xDDEFF5),
        wrong: Color(hex: 0xD32F2F),
        accent: Color(hex: 0x2E7D9A)
    )

    static let dark = CrosswordColors(
        background: Color(hex: 0x1B1F24),
        blockMark: Color(hex: 0x050607),
        line: Color(hex: 0x555E6C),
        letter: Color(hex: 0xE9ECF1),
        number: Color(hex: 0xB8BEC8),
        selected: Color(hex: 0x2F6F88),
        word: Color(hex: 0x1C3440),
        wrong: Color(hex: 0xFF6B6B),
        accent: Color(hex: 0x6FB8D2)
    )

    static func of(_ scheme: ColorScheme) -> CrosswordColors {
        scheme == .dark ? dark : light
    }
}
