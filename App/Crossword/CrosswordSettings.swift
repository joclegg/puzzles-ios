import Foundation

enum CrosswordToggle: String, CaseIterable {
    case showTimer = "show_timer"
    case showMistakes = "show_mistakes"
    case allowReveal = "allow_reveal"
    case skipFilledCells = "skip_filled_cells"

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
        }
    }

    var defaultValue: Bool {
        switch self {
        case .showTimer, .skipFilledCells:
            true
        case .showMistakes, .allowReveal:
            false
        }
    }
}

struct CrosswordSettings {
    private let toggles: [CrosswordToggle: Bool]

    init(defaults: UserDefaults = .standard) {
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
