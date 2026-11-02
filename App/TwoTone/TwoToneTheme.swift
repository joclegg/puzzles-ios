import SwiftUI
import UIKit

enum TwoToneColors {
    static let emptyTile = dynamic(0xE6E9EE, 0x2A2E35)
    static let red = dynamic(0xE0603F, 0xD5583A)
    static let redEdge = dynamic(0xB54A30, 0xA6432C)
    static let blue = dynamic(0x34A7C8, 0x2E9EBE)
    static let blueEdge = dynamic(0x2785A0, 0x227A93)
    static let broken = dynamic(0x14181F, 0xF1F3F6)
    static let hintLine = dynamic(0xE5F0FE, 0x1A2B40)
    static let hintTarget = dynamic(0x1565D8, 0x7DB5FF)
    static let accent = dynamic(0xE0603F, 0xEC7F62)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(light: light, dark: dark)
    }
}

enum TwoToneSettingKey {
    static let inputMode = "two_tone_input_mode"
    static let markBrokenRules = "two_tone_mark_broken_rules"
    static let showTimer = "two_tone_show_timer"
    static let showProgress = "two_tone_show_progress"
    static let showHints = "two_tone_show_hints"
    static let showTutorial = "two_tone_show_tutorial"
    static let allowReveal = "two_tone_allow_reveal"
}

enum TwoToneInputMode {
    static let tapToCycle = "TAP_TO_CYCLE"
    static let pickColour = "PICK_COLOUR"
}

struct TwoToneDialog<Content: View, Buttons: View>: View {
    let title: String
    var tag: String?
    let onDismiss: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title3.bold())
                content
                HStack(spacing: 16) {
                    Spacer()
                    buttons
                }
            }
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 28))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tag ?? "dialog")
        }
    }
}
