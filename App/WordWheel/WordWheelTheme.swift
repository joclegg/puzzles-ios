import SwiftUI
import UIKit

enum WordWheelSetting {
    static let showTimer = "word_wheel_show_timer"
    static let showBonusCount = "word_wheel_show_bonus_count"
    static let showHints = "word_wheel_show_hints"
    static let showTutorial = "word_wheel_show_tutorial"
    static let allowReveal = "word_wheel_allow_reveal"
}

enum WheelColors {
    static let cell = dynamic(0xE6E9EE, 0x2A2E35)
    static let cellFound = dynamic(0x1565D8, 0x2F5E99)
    static let cellHinted = dynamic(0xBCD9FC, 0x244A78)
    static let cellText = dynamic(0xFFFFFF, 0xE9ECF1)
    static let wheel = dynamic(0xE5F0FE, 0x1A2B40)
    static let letter = dynamic(0xFFFFFF, 0x2A2E35)
    static let letterText = dynamic(0x14181F, 0xE9ECF1)
    static let chosen = dynamic(0x1565D8, 0x7DB5FF)
    static let chosenText = dynamic(0xFFFFFF, 0x0B2545)
    static let line = dynamic(0x1565D8, 0x7DB5FF)
    static let accent = dynamic(0x4F5BD5, 0x939BFF)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                color(traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct WordWheelDialogCard<Content: View>: View {
    let tag: String?
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tag ?? "")
        }
    }
}

struct WordWheelConfirm: View {
    let title: String
    let message: String
    var tag: String?
    let confirm: String
    let confirmTag: String
    let dismiss: String
    var dismissTag: String?
    let onConfirm: () -> Void
    let onDismissButton: () -> Void
    let onCancel: () -> Void

    var body: some View {
        WordWheelDialogCard(tag: tag, onDismiss: onCancel) {
            Text(title).font(.title3.bold())
            Text(message).font(.body)
            HStack(spacing: 16) {
                Spacer()
                Button(dismiss, action: onDismissButton)
                    .accessibilityIdentifier(dismissTag ?? "")
                Button(confirm, action: onConfirm)
                    .accessibilityIdentifier(confirmTag)
            }
            .tint(WheelColors.accent)
        }
    }
}
