import Foundation
import SudokuEngine

enum HelperDefaults {
    private static let migratedKey = "helper_defaults_migrated"

    static func preserveForExistingUsers(
        defaults: UserDefaults = .standard,
        existingInstall: Bool = FileManager.default.fileExists(
            atPath: URL.applicationSupportDirectory.appending(path: "puzzles-data").path(percentEncoded: false))
    ) {
        #if DEBUG
            if defaults.string(forKey: "helpers") == "on" {
                for (key, value) in previousDefaults {
                    defaults.set(value, forKey: key)
                }
            }
        #endif
        guard !defaults.bool(forKey: migratedKey) else {
            return
        }
        defaults.set(true, forKey: migratedKey)
        guard existingInstall else {
            return
        }
        for (key, value) in previousDefaults where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    static var previousDefaults: [String: Any] {
        var values: [String: Any] = [:]
        let sudokuToggles: [SettingToggle] = [
            .showMistakeCount, .highlightHouses, .highlightCage, .autoRemoveNotes, .disableCompletedDigits, .highlightLastPlaced,
            .showHints, .allowReveal,
        ]
        for mode in GameMode.allCases {
            for toggle in sudokuToggles {
                values[toggle.key(mode)] = true
            }
            values[SettingKeys.mistakes(mode)] = MistakeCheck.showWrong.rawValue
            values[SettingKeys.sameNumber(mode)] = HighlightStyle.cell.rawValue
            values[SettingKeys.notes(mode)] = HighlightStyle.cell.rawValue
            values[SettingKeys.digitCounts(mode)] = DigitCounts.countUp.rawValue
        }
        let flags = [
            "solitaire_warn_unwinnable", "solitaire_show_hints", "solitaire_allow_reveal",
            "two_tone_mark_broken_rules", "two_tone_show_progress", "two_tone_show_hints", "two_tone_allow_reveal",
            "sightlines_mark_broken_rules", "sightlines_show_progress", "sightlines_show_seen_count", "sightlines_show_hints",
            "sightlines_allow_reveal",
            "fiveLetters.show_hints", "fiveLetters.allow_reveal",
            "kakuro_show_mistake_count", "kakuro_auto_remove_notes", "kakuro_highlight_runs", "kakuro_grey_used_digits",
            "kakuro_show_hints", "kakuro_allow_reveal",
            "slideout_show_hints", "slideout_allow_reveal",
            "word_wheel_show_hints", "word_wheel_allow_reveal",
        ]
        for flag in flags {
            values[flag] = true
        }
        values["kakuro_mistake_check"] = "showWrong"
        return values
    }
}
