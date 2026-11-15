import CrosswordEngine
import SwiftUI
import UIKit

enum CrosswordKey: Equatable {
    case letter(Character)
    case backspace
    case space
    case arrow(Arrow)
    case tab(backward: Bool)
}

final class CrosswordKeyInputView: UIView, UIKeyInput {
    var onKey: (CrosswordKey) -> Void = { _ in }
    var active = true

    var autocorrectionType: UITextAutocorrectionType = .no
    var spellCheckingType: UITextSpellCheckingType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .allCharacters
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .asciiCapable
    var inlinePredictionType: UITextInlinePredictionType = .no
    var returnKeyType: UIReturnKeyType = .next

    override var canBecomeFirstResponder: Bool {
        true
    }

    var hasText: Bool {
        true
    }

    func insertText(_ text: String) {
        for character in text {
            if character == " " {
                onKey(.space)
            } else if character == "\t" {
                onKey(.tab(backward: false))
            } else if character.isLetter {
                onKey(.letter(character))
            }
        }
    }

    func deleteBackward() {
        onKey(.backspace)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        claimFocus()
    }

    func claimFocus() {
        guard window != nil else {
            return
        }
        if active && !isFirstResponder {
            becomeFirstResponder()
        } else if !active && isFirstResponder {
            resignFirstResponder()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled: Set<UIPress> = []
        for press in presses {
            guard let key = press.key, let mapped = Self.map(key) else {
                unhandled.insert(press)
                continue
            }
            onKey(mapped)
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    private static func map(_ key: UIKey) -> CrosswordKey? {
        switch key.keyCode {
        case .keyboardUpArrow:
            .arrow(.up)
        case .keyboardDownArrow:
            .arrow(.down)
        case .keyboardLeftArrow:
            .arrow(.left)
        case .keyboardRightArrow:
            .arrow(.right)
        case .keyboardTab:
            .tab(backward: key.modifierFlags.contains(.shift))
        default:
            nil
        }
    }
}

struct CrosswordKeyInput: UIViewRepresentable {
    let active: Bool
    let onKey: (CrosswordKey) -> Void

    func makeUIView(context: Context) -> CrosswordKeyInputView {
        let view = CrosswordKeyInputView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.accessibilityIdentifier = "crossword_keyboard"
        view.onKey = onKey
        view.active = active
        return view
    }

    func updateUIView(_ view: CrosswordKeyInputView, context: Context) {
        view.onKey = onKey
        view.active = active
        view.claimFocus()
    }
}
