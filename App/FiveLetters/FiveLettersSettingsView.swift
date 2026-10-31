import SwiftUI

enum FiveLettersSetting: String, CaseIterable, Identifiable {
    case hardMode = "hard_mode"
    case highContrast = "high_contrast"
    case showHints = "show_hints"
    case showTutorial = "show_tutorial"
    case allowReveal = "allow_reveal"

    var id: String {
        rawValue
    }

    var key: String {
        "fiveLetters.\(rawValue)"
    }

    var defaultValue: Bool {
        switch self {
        case .hardMode, .highContrast:
            false
        case .showHints, .showTutorial, .allowReveal:
            true
        }
    }

    var title: String {
        switch self {
        case .hardMode:
            "Hard mode"
        case .highContrast:
            "High contrast colours"
        case .showHints:
            "Hints"
        case .showTutorial:
            "How to play"
        case .allowReveal:
            "Show solution"
        }
    }

    var detail: String {
        switch self {
        case .hardMode:
            "Every green and yellow letter you find must be used in later guesses. Applies to new games."
        case .highContrast:
            "Orange and blue instead of green and yellow."
        case .showHints:
            "Show the hint button."
        case .showTutorial:
            "Show the ? button with the rules and a walkthrough."
        case .allowReveal:
            "Offer Show solution in the game menu."
        }
    }

    var current: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
}

struct FiveLettersSettingsView: View {
    var body: some View {
        Form {
            ForEach(FiveLettersSetting.allCases) { setting in
                FiveLettersSettingRow(setting: setting)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FiveLettersSettingRow: View {
    let setting: FiveLettersSetting
    @AppStorage private var enabled: Bool

    init(setting: FiveLettersSetting) {
        self.setting = setting
        _enabled = AppStorage(wrappedValue: setting.defaultValue, setting.key)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(setting.title)
                Text(setting.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Toggle(setting.title, isOn: $enabled)
                .labelsHidden()
                .accessibilityIdentifier("setting_\(setting.rawValue)")
        }
    }
}
