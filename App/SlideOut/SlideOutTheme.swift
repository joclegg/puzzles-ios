import SlideOutEngine
import SwiftUI
import UIKit

struct SlideColors {
    let board: Color
    let slot: Color
    let block: Color
    let blockEdge: Color
    let target: Color
    let targetEdge: Color
    let exit: Color
    let hint: Color
    let accent: Color

    private static let light = SlideColors(
        board: Color(slideHex: 0x263040),
        slot: Color(slideHex: 0x353A42),
        block: Color(slideHex: 0xD9B98A),
        blockEdge: Color(slideHex: 0xB09068),
        target: Color(slideHex: 0xE0603F),
        targetEdge: Color(slideHex: 0xB54A30),
        exit: Color(slideHex: 0xE0603F),
        hint: Color(slideHex: 0x8EC0FA),
        accent: Color(slideHex: 0xC27A2C)
    )

    private static let dark = SlideColors(
        board: Color(slideHex: 0x15191F),
        slot: Color(slideHex: 0x22272E),
        block: Color(slideHex: 0xB59A72),
        blockEdge: Color(slideHex: 0x8C7354),
        target: Color(slideHex: 0xD5583A),
        targetEdge: Color(slideHex: 0xA6432C),
        exit: Color(slideHex: 0xD5583A),
        hint: Color(slideHex: 0x7DB5FF),
        accent: Color(slideHex: 0xE3A85C)
    )

    static func of(_ scheme: ColorScheme) -> SlideColors {
        scheme == .dark ? dark : light
    }
}

extension Color {
    fileprivate init(slideHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum SlideOutSettingKey {
    static let showTimer = "slideout_show_timer"
    static let showPar = "slideout_show_par"
    static let showHints = "slideout_show_hints"
    static let showTutorial = "slideout_show_tutorial"
    static let allowReveal = "slideout_allow_reveal"
}

private let tileFill = Color.primary.opacity(0.05)
private let tileBorder = Color.primary.opacity(0.12)

struct SlideOutBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
    }
}

struct SlideOutIconButton: View {
    let systemName: String
    let label: String
    let id: String
    var enabled = true
    let action: () -> Void
    @State private var showTip = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).frame(width: 40, height: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in
                showTip = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showTip = false
                }
            }
        )
        .overlay(alignment: .bottom) {
            if showTip {
                Text(label)
                    .font(.caption)
                    .fixedSize()
                    .padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .offset(y: 32)
            }
        }
        .zIndex(showTip ? 1 : 0)
    }
}

struct SlideOutSection<Content: View>: View {
    let title: String
    var aside: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased()).fontWeight(.semibold).tracking(1.2)
                Spacer()
                if let aside {
                    Text(aside)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            content
        }
    }
}

struct SlideOutPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileFill, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(tileBorder))
    }
}

struct SlideOutHero: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            SlideOutGameIcon()
                .frame(width: 80, height: 80)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 1)
            Text("Slide the blocks to free the red one").foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.2), accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.25)))
    }
}

struct SlideOutGameIcon: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = SlideColors.of(scheme)
        ZStack(alignment: .topLeading) {
            piece(colors.target, x: 4, y: 22, width: 30, height: 13)
            piece(colors.block, x: 37, y: 4, width: 14, height: 30)
            piece(colors.block, x: 4, y: 39, width: 30, height: 13)
            Rectangle().fill(colors.exit).frame(width: 3, height: 13).offset(x: 53, y: 22)
        }
        .frame(width: 56, height: 56, alignment: .topLeading)
        .background(colors.board, in: RoundedRectangle(cornerRadius: 8))
    }

    private func piece(_ color: Color, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: width, height: height).offset(x: x, y: y)
    }
}

struct SlideOutDialog<Content: View, Buttons: View>: View {
    let id: String?
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }
            VStack(alignment: .leading, spacing: 12) {
                content
                HStack(spacing: 16) {
                    Spacer()
                    buttons
                }
            }
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id ?? "dialog")
        }
    }
}

struct SlideOutBackSwipe: UIViewControllerRepresentable {
    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}
}

extension View {
    func slideOutScreen() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
            .background(SlideOutBackSwipe().frame(width: 0, height: 0))
    }
}
