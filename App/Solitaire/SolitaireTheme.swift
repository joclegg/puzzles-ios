import SwiftUI
import UIKit

extension Color {
    fileprivate init(solitaireLight light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255,
                    alpha: CGFloat((value >> 24) & 0xFF) / 255
                )
            }
        )
    }
}

enum SolitaireColors {
    static let felt = Color(solitaireLight: 0xFF2E_6B4A, dark: 0xFF15_301F)
    static let emptyPile = Color(solitaireLight: 0x33FF_FFFF, dark: 0x26FF_FFFF)
    static let cardFace = Color(solitaireLight: 0xFFFF_FFFF, dark: 0xFFE3_E6EA)
    static let cardEdge = Color(solitaireLight: 0xFFA7_AFBB, dark: 0xFF55_5E6C)
    static let cardBack = Color(solitaireLight: 0xFF15_65D8, dark: 0xFF2F_5E99)
    static let cardBackPattern = Color(solitaireLight: 0xFF8E_C0FA, dark: 0xFF7D_B5FF)
    static let blackSuit = Color(solitaireLight: 0xFF14_181F, dark: 0xFF12_1418)
    static let redSuit = Color(solitaireLight: 0xFFC6_2828, dark: 0xFFB3_261E)
    static let selected = Color(solitaireLight: 0xFF8E_C0FA, dark: 0xFF7D_B5FF)
    static let onFelt = Color(solitaireLight: 0xFFF1_F5F2, dark: 0xFFDD_E1E7)
    static let accent = Color(solitaireLight: 0xFF2E_8B57, dark: 0xFF5C_C58A)
    static let primary = Color(solitaireLight: 0xFF15_65D8, dark: 0xFF7D_B5FF)
    static let background = Color(solitaireLight: 0xFFFF_FFFF, dark: 0xFF12_1418)
    static let tile = Color(solitaireLight: 0xFFFF_FFFF, dark: 0xFF1C_2026)
    static let onSurface = Color(solitaireLight: 0xFF14_181F, dark: 0xFFE9_ECF1)
    static let onSurfaceVariant = Color(solitaireLight: 0xFF5A_6270, dark: 0xFFA7_AFBB)
}

struct SolitaireBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PuzzleIcon.image("chevron.left")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("back")
        .tint(SolitaireColors.onSurface)
    }
}

struct SolitaireIconButton: View {
    let symbol: String
    let label: String
    let tag: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PuzzleIcon.image(symbol)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
        .tint(SolitaireColors.onSurface)
    }
}

struct SolitaireDialog<Content: View>: View {
    let tag: String?
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        let body = VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SolitaireColors.background, in: RoundedRectangle(cornerRadius: 24))
        .padding(24)
        .foregroundStyle(SolitaireColors.onSurface)
        .accessibilityElement(children: .contain)
        if let tag {
            body.accessibilityIdentifier(tag)
        } else {
            body
        }
    }
}

struct SolitaireTextButton: View {
    let title: String
    let tag: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .disabled(!enabled)
            .tint(SolitaireColors.primary)
            .accessibilityIdentifier(tag)
    }
}

private final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()
    weak var navigation: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigation?.viewControllers.count ?? 0) > 1
    }
}

private final class SwipeBackController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let navigationController else {
            return
        }
        SwipeBackDelegate.shared.navigation = navigationController
        navigationController.interactivePopGestureRecognizer?.delegate = SwipeBackDelegate.shared
        navigationController.interactivePopGestureRecognizer?.isEnabled = true
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    func solitaireScreen() -> some View {
        background(SolitaireColors.background.ignoresSafeArea())
            .background(SwipeBackEnabler().frame(width: 0, height: 0))
            .foregroundStyle(SolitaireColors.onSurface)
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
    }
}
