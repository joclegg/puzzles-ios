import SwiftUI

struct KakuroColors {
    let background: Color
    let block: Color
    let clue: Color
    let line: Color
    let givenCell: Color
    let digit: Color
    let note: Color
    let selected: Color
    let run: Color
    let sameDigit: Color
    let wrong: Color
    let trialMark: Color
    let accent: Color

    static let light = KakuroColors(
        background: Color(hex: 0xFFFFFF),
        block: Color(hex: 0x263040),
        clue: Color(hex: 0xF1F3F6),
        line: Color(hex: 0xA7AFBB),
        givenCell: Color(hex: 0xD5D8DD),
        digit: Color(hex: 0x14181F),
        note: Color(hex: 0x4A515B),
        selected: Color(hex: 0x8EC0FA),
        run: Color(hex: 0xE5F0FE),
        sameDigit: Color(hex: 0xBCD9FC),
        wrong: Color(hex: 0xD32F2F),
        trialMark: Color(hex: 0xE53935),
        accent: Color(hex: 0x7C5CD6)
    )

    static let dark = KakuroColors(
        background: Color(hex: 0x121418),
        block: Color(hex: 0x2A2E35),
        clue: Color(hex: 0xDDE1E7),
        line: Color(hex: 0x555E6C),
        givenCell: Color(hex: 0x353A42),
        digit: Color(hex: 0xE9ECF1),
        note: Color(hex: 0xB8BEC8),
        selected: Color(hex: 0x2F5E99),
        run: Color(hex: 0x1A2B40),
        sameDigit: Color(hex: 0x244A78),
        wrong: Color(hex: 0xFF6B6B),
        trialMark: Color(hex: 0xFF5252),
        accent: Color(hex: 0xA993F2)
    )

    static func of(_ scheme: ColorScheme) -> KakuroColors {
        scheme == .dark ? dark : light
    }
}
