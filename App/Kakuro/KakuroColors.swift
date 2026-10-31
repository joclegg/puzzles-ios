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
        background: Color(kakuroHex: 0xFFFFFF),
        block: Color(kakuroHex: 0x263040),
        clue: Color(kakuroHex: 0xF1F3F6),
        line: Color(kakuroHex: 0xA7AFBB),
        givenCell: Color(kakuroHex: 0xD5D8DD),
        digit: Color(kakuroHex: 0x14181F),
        note: Color(kakuroHex: 0x4A515B),
        selected: Color(kakuroHex: 0x8EC0FA),
        run: Color(kakuroHex: 0xE5F0FE),
        sameDigit: Color(kakuroHex: 0xBCD9FC),
        wrong: Color(kakuroHex: 0xD32F2F),
        trialMark: Color(kakuroHex: 0xE53935),
        accent: Color(kakuroHex: 0x7C5CD6)
    )

    static let dark = KakuroColors(
        background: Color(kakuroHex: 0x121418),
        block: Color(kakuroHex: 0x2A2E35),
        clue: Color(kakuroHex: 0xDDE1E7),
        line: Color(kakuroHex: 0x555E6C),
        givenCell: Color(kakuroHex: 0x353A42),
        digit: Color(kakuroHex: 0xE9ECF1),
        note: Color(kakuroHex: 0xB8BEC8),
        selected: Color(kakuroHex: 0x2F5E99),
        run: Color(kakuroHex: 0x1A2B40),
        sameDigit: Color(kakuroHex: 0x244A78),
        wrong: Color(kakuroHex: 0xFF6B6B),
        trialMark: Color(kakuroHex: 0xFF5252),
        accent: Color(kakuroHex: 0xA993F2)
    )

    static func of(_ scheme: ColorScheme) -> KakuroColors {
        scheme == .dark ? dark : light
    }
}

extension Color {
    fileprivate init(kakuroHex hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
