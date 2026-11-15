import Foundation

enum CrosswordToggle: String, CaseIterable {
    case showTimer = "show_timer"
    case showMistakes = "show_mistakes"
    case allowReveal = "allow_reveal"
    case skipFilledCells = "skip_filled_cells"
    case showHints = "show_hints"

    var key: String {
        "crossword_\(rawValue)"
    }

    var jsonName: String {
        switch self {
        case .showTimer:
            "showTimer"
        case .showMistakes:
            "showMistakes"
        case .allowReveal:
            "allowReveal"
        case .skipFilledCells:
            "skipFilledCells"
        case .showHints:
            "showHints"
        }
    }

    var defaultValue: Bool {
        switch self {
        case .showTimer, .skipFilledCells:
            true
        case .showMistakes, .allowReveal, .showHints:
            false
        }
    }
}

enum CrosswordKeys {
    static let hintFill = "crossword_hint_fill"
}

struct CrosswordSettings {
    let hintFill: Bool
    private let toggles: [CrosswordToggle: Bool]

    init(defaults: UserDefaults = .standard) {
        hintFill = defaults.bool(forKey: CrosswordKeys.hintFill)
        var read: [CrosswordToggle: Bool] = [:]
        for toggle in CrosswordToggle.allCases {
            read[toggle] = defaults.object(forKey: toggle.key) as? Bool ?? toggle.defaultValue
        }
        toggles = read
    }

    func isOn(_ toggle: CrosswordToggle) -> Bool {
        toggles[toggle] ?? toggle.defaultValue
    }
}
