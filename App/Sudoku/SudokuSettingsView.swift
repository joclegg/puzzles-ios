import SudokuEngine
import SwiftUI

struct SudokuGeneralSettings: View {
    @AppStorage(SettingKeys.theme) private var theme = ThemeMode.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance").font(.headline)
            SudokuSegments(
                options: ThemeMode.allCases, selected: ThemeMode(rawValue: theme) ?? .system,
                label: { $0.rawValue.capitalized }, id: { "setting_theme_\($0.rawValue.lowercased())" },
                onSelect: { theme = $0.rawValue })
            Text("Applies to every game.").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .modifier(SudokuTileStyle())
        .padding(16)
    }
}

struct SudokuSettingsView: View {
    let initialMode: GameMode
    @State private var mode: GameMode?
    @AppStorage(SettingKeys.inputMode) private var inputMode = InputMode.cellFirst.rawValue

    private var shown: GameMode {
        mode ?? initialMode
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                general
                VStack(alignment: .leading, spacing: 12) {
                    SudokuSegments(
                        options: GameMode.allCases, selected: shown, label: \.label, id: { "settings_tab_\($0.slug)" },
                        onSelect: { mode = $0 })
                    SudokuModeSettingsForm(mode: shown).id(shown)
                }
                .padding(16)
                .modifier(SudokuTileStyle())
            }
            .padding(16)
        }
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General").font(.title2)
            sudokuSection("Entering numbers")
            SudokuSegments(
                options: InputMode.allCases, selected: InputMode(rawValue: inputMode) ?? .cellFirst,
                label: { $0 == .cellFirst ? "Cell first" : "Number first" },
                id: { "setting_\($0.rawValue.lowercased())" }, onSelect: { inputMode = $0.rawValue })
            sudokuHint(
                inputMode == InputMode.cellFirst.rawValue
                    ? "Tap a cell, then pick its number. Try number first: it's faster once you're used to it. Applies to both modes."
                    : "Pick a number, then tap every cell it goes in. Applies to both modes.")
        }
        .padding(16)
        .modifier(SudokuTileStyle())
    }
}

private func sudokuSection(_ title: String) -> some View {
    Text(title).font(.headline).foregroundStyle(.tint).padding(.top, 8)
}

private func sudokuHint(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary)
}

private struct SudokuModeSettingsForm: View {
    let mode: GameMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sudokuSection("Mistakes")
            SudokuStoredChoice(
                key: SettingKeys.mistakes(mode), fallback: ModeSettings.defaultMistakeCheck, options: MistakeCheck.allCases,
                label: { level in
                    switch level {
                    case .off:
                        "Off"
                    case .blockClashes:
                        "Block clashes"
                    case .showWrong:
                        "Show wrong"
                    }
                }, tag: { "setting_mistakes_\($0.rawValue.lowercased())" })
            sudokuHint(
                "Block clashes refuses a number already in the row, column, box or cage. Show wrong turns any wrong number red. Applies to new games."
            )
            row(.showMistakeCount, "Show mistake counter")
            sudokuSection("Highlighting")
            row(.highlightHouses, "Row, column and box", detail: "Around the selected cell")
            if mode == .killer {
                row(.highlightCage, "Cage", detail: "The selected cell's cage")
            }
            style("Same number", SettingKeys.sameNumber(mode), "same_number")
            style("Matching pencil marks", SettingKeys.notes(mode), "notes")
            sudokuHint("Cell shades the whole cell; number colours just the digit.")
            row(
                .highlightLastPlaced, "Highlight the cell you just filled",
                detail: "Keep it and its row, column and box highlighted")
            sudokuSection("Look")
            row(.greyGivenCells, "Grey starting cells")
            row(.boldPlacedDigits, "Bold numbers you place", detail: "Heavier than the starting numbers")
            sudokuSection("Playing")
            row(.autoRemoveNotes, "Clear pencil marks automatically", detail: "When you place a number")
            Text("Number counts")
            SudokuStoredChoice(
                key: SettingKeys.digitCounts(mode), fallback: ModeSettings.defaultDigitCounts, options: DigitCounts.allCases,
                label: { counts in
                    switch counts {
                    case .countUp:
                        "Count up"
                    case .countDown:
                        "Count down"
                    case .off:
                        "Off"
                    }
                }, tag: { "setting_counts_\($0.rawValue.lowercased())" })
            sudokuHint("Count up shows how many of each number are placed; count down shows how many are left.")
            row(.disableCompletedDigits, "Disable finished numbers", detail: "Once all are placed")
            row(.showTimer, "Show timer", detail: "Best times are still recorded")
            sudokuSection("Help")
            SudokuHintsRows(mode: mode)
            row(.showTutorial, "How to play", detail: "Show the ? button with the rules and a walkthrough.")
            row(.allowReveal, "Show solution", detail: "Offer Show solution in the game menu.")
        }
    }

    private func row(_ toggle: SettingToggle, _ title: String, detail: String? = nil) -> some View {
        SudokuToggleRow(
            key: toggle.key(mode), fallback: toggle.defaultFor(mode), title: title, detail: detail,
            id: "setting_\(toggle.rawValue)")
    }

    private func style(_ title: String, _ key: String, _ tag: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            SudokuStoredChoice(
                key: key, fallback: ModeSettings.defaultHighlightStyle, options: HighlightStyle.allCases,
                label: { $0.rawValue.capitalized }, tag: { "setting_\(tag)_\($0.rawValue.lowercased())" })
        }
    }
}

private struct SudokuHintsRows: View {
    let mode: GameMode
    @AppStorage private var hints: Bool
    @AppStorage private var style: String

    init(mode: GameMode) {
        self.mode = mode
        _hints = AppStorage(wrappedValue: SettingToggle.showHints.defaultFor(mode), SettingToggle.showHints.key(mode))
        _style = AppStorage(wrappedValue: HintStyle.point.rawValue, SettingKeys.hintStyle(mode))
    }

    var body: some View {
        SudokuToggleRow(
            key: SettingToggle.showHints.key(mode), fallback: SettingToggle.showHints.defaultFor(mode), title: "Hints",
            detail: "Show the hint button.", id: "setting_show_hints")
        if hints {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hints fill the answer in")
                    sudokuHint("Off: a hint points at the next step and says why.")
                }
                Spacer()
                Toggle(
                    "Hints fill the answer in",
                    isOn: Binding(
                        get: { style == HintStyle.fill.rawValue },
                        set: { style = $0 ? HintStyle.fill.rawValue : HintStyle.point.rawValue })
                )
                .labelsHidden()
                .accessibilityIdentifier("setting_hint_fill")
            }
        }
    }
}

private struct SudokuToggleRow: View {
    let title: String
    let detail: String?
    let id: String
    @AppStorage private var on: Bool

    init(key: String, fallback: Bool, title: String, detail: String?, id: String) {
        self.title = title
        self.detail = detail
        self.id = id
        _on = AppStorage(wrappedValue: fallback, key)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    sudokuHint(detail)
                }
            }
            Spacer()
            Toggle(title, isOn: $on)
                .labelsHidden()
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier(id)
        }
    }
}

private struct SudokuStoredChoice<Option: RawRepresentable & Hashable>: View where Option.RawValue == String {
    let fallback: Option
    let options: [Option]
    let label: (Option) -> String
    let tag: (Option) -> String
    @AppStorage private var stored: String

    init(
        key: String, fallback: Option, options: [Option], label: @escaping (Option) -> String,
        tag: @escaping (Option) -> String
    ) {
        self.fallback = fallback
        self.options = options
        self.label = label
        self.tag = tag
        _stored = AppStorage(wrappedValue: fallback.rawValue, key)
    }

    var body: some View {
        SudokuSegments(
            options: options, selected: Option(rawValue: stored) ?? fallback, label: label, id: tag,
            onSelect: { stored = $0.rawValue })
    }
}
