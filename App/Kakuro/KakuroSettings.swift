import Foundation
import KakuroEngine

enum KakuroToggle: String, CaseIterable {
    case showMistakeCount = "show_mistake_count"
    case autoRemoveNotes = "auto_remove_notes"
    case highlightRuns = "highlight_runs"
    case showTimer = "show_timer"
    case showCombinations = "show_combinations"
    case greyUsedDigits = "grey_used_digits"
    case showHints = "show_hints"
    case showTutorial = "show_tutorial"
    case allowReveal = "allow_reveal"

    var key: String {
        "kakuro_\(rawValue)"
    }

    var defaultValue: Bool {
        self != .showCombinations
    }
}

enum KakuroKeys {
    static let inputMode = "kakuro_input_mode"
    static let mistakeCheck = "kakuro_mistake_check"
    static let hintFill = "kakuro_hint_fill"
}

struct KakuroSettings {
    let inputMode: InputMode
    let mistakeCheck: MistakeCheck
    let hintFill: Bool
    private let toggles: [KakuroToggle: Bool]

    init(defaults: UserDefaults = .standard) {
        inputMode = defaults.string(forKey: KakuroKeys.inputMode).flatMap(InputMode.init(rawValue:)) ?? .cellFirst
        mistakeCheck = defaults.string(forKey: KakuroKeys.mistakeCheck).flatMap(MistakeCheck.init(rawValue:)) ?? .showWrong
        hintFill = defaults.bool(forKey: KakuroKeys.hintFill)
        var read: [KakuroToggle: Bool] = [:]
        for toggle in KakuroToggle.allCases {
            read[toggle] = defaults.object(forKey: toggle.key) as? Bool ?? toggle.defaultValue
        }
        toggles = read
    }

    func isOn(_ toggle: KakuroToggle) -> Bool {
        toggles[toggle] ?? toggle.defaultValue
    }
}
