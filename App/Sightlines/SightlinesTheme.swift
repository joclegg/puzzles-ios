import SwiftUI
import UIKit

extension Color {
    fileprivate init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat(value >> 16 & 0xFF) / 255,
                    green: CGFloat(value >> 8 & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255,
                    alpha: 1
                )
            }
        )
    }
}

enum SightlinesColors {
    static let emptyTile = Color(light: 0xE6E9EE, dark: 0x2A2E35)
    static let red = Color(light: 0xE0603F, dark: 0xD5583A)
    static let redEdge = Color(light: 0xB54A30, dark: 0xA6432C)
    static let blue = Color(light: 0x34A7C8, dark: 0x2E9EBE)
    static let blueEdge = Color(light: 0x2785A0, dark: 0x227A93)
    static let number = Color(light: 0xFFFFFF, dark: 0xF1F3F6)
    static let broken = Color(light: 0x14181F, dark: 0xF1F3F6)
    static let hintLine = Color(light: 0xE5F0FE, dark: 0x1A2B40)
    static let hintTarget = Color(light: 0x1565D8, dark: 0x7DB5FF)
    static let accent = Color(light: 0x2A93B3, dark: 0x52BDDC)
    static let tile = Color.primary.opacity(0.05)
    static let tileBorder = Color.primary.opacity(0.12)
}

struct SightlinesGameIcon: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                square(SightlinesColors.blue, "2")
                square(SightlinesColors.red, nil)
            }
            HStack(spacing: 4) {
                square(SightlinesColors.blue, nil)
                square(SightlinesColors.blue, "1")
            }
        }
    }

    private func square(_ colour: Color, _ label: String?) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(colour)
            .frame(width: 26, height: 26)
            .overlay {
                if let label {
                    Text(label).font(.system(size: 14, weight: .bold)).foregroundStyle(SightlinesColors.number)
                }
            }
    }
}

struct SightlinesDialog<Content: View>: View {
    let tag: String
    var dismiss: (() -> Void)?
    var border: Color = .clear
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss?() }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(border))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tag)
            .padding(24)
        }
    }
}

extension Text {
    func sightlinesDialogAction(_ tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self.fontWeight(.medium).foregroundStyle(SightlinesColors.accent).padding(.vertical, 6)
        }
        .accessibilityIdentifier(tag)
    }
}
