import Foundation
import PuzzlesCore
import SudokuEngine

func sudokuDate(_ day: CalendarDay) -> Date {
    let parts = day.isoString.split(separator: "-").compactMap { Int($0) }
    let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
    return Calendar.current.date(from: components) ?? Date()
}

@MainActor
func sudokuModeSettings(_ mode: GameMode) -> ModeSettings {
    let defaults = UserDefaults.standard
    return ModeSettings(
        mode: mode,
        bool: { defaults.object(forKey: $0) as? Bool },
        string: { defaults.string(forKey: $0) }
    )
}

@MainActor
func sudokuInputMode() -> InputMode {
    UserDefaults.standard.string(forKey: SettingKeys.inputMode).flatMap(InputMode.init(rawValue:)) ?? .cellFirst
}
