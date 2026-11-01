import KakuroEngine
import SwiftUI

struct KakuroSettingsView: View {
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @AppStorage(KakuroKeys.inputMode) private var inputMode = InputMode.cellFirst.rawValue
    @AppStorage(KakuroKeys.mistakeCheck) private var mistakeCheck = MistakeCheck.off.rawValue
    @AppStorage(KakuroKeys.hintFill) private var hintFill = false
    @AppStorage(KakuroToggle.showHints.key) private var showHints = KakuroToggle.showHints.defaultValue
    @AppStorage(KakuroToggle.showCombinations.key) private var showCombinations = KakuroToggle.showCombinations.defaultValue
    @AppStorage(KakuroKeys.combinationOrder) private var combinationOrder = CombinationOrder.increasing.rawValue

    private var accent: Color {
        KakuroColors.of(scheme).accent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Entering numbers").font(.headline)
                    choice(
                        [
                            ("Cell first", InputMode.cellFirst.rawValue, "setting_cell_first"),
                            ("Number first", InputMode.digitFirst.rawValue, "setting_digit_first"),
                        ], selection: $inputMode)
                    hint("Cell first: tap a cell, then a number. Number first: pick a number, then tap cells to fill them.")
                    Text("Mistakes").font(.headline)
                    choice(
                        [
                            ("Off", MistakeCheck.off.rawValue, "setting_mistakes_off"),
                            ("Block clashes", MistakeCheck.blockClashes.rawValue, "setting_mistakes_block_clashes"),
                            ("Show wrong", MistakeCheck.showWrong.rawValue, "setting_mistakes_show_wrong"),
                        ], selection: $mistakeCheck)
                    hint(
                        "Block clashes refuses a number already in the run. Show wrong turns any wrong number red. "
                            + "Both turn runs that can no longer add up red, and count mistakes.")
                    KakuroToggleRow(toggle: .showMistakeCount, title: "Show the mistake counter")
                    KakuroToggleRow(
                        toggle: .autoRemoveNotes, title: "Remove pencil marks automatically",
                        detail: "Placing a number clears that number's pencil marks from its across and down runs.")
                    KakuroToggleRow(
                        toggle: .highlightRuns, title: "Highlight runs", detail: "Shade the across and down runs of the selected cell.")
                    KakuroToggleRow(toggle: .showTimer, title: "Show the timer")
                    KakuroToggleRow(
                        toggle: .showCombinations, title: "Sum helper",
                        detail: "List the digit combinations that still fit the selected cell's runs.")
                    if showCombinations {
                        choice(
                            [
                                ("Increasing", CombinationOrder.increasing.rawValue, "setting_combination_order_increasing"),
                                ("Decreasing", CombinationOrder.decreasing.rawValue, "setting_combination_order_decreasing"),
                            ], selection: $combinationOrder)
                        hint("The order the sum helper lists its numbers in.")
                    }
                    KakuroToggleRow(
                        toggle: .greyUsedDigits, title: "Grey out used-up numbers",
                        detail: "Dim a number on the pad once every cell that needs it has it.")
                    KakuroToggleRow(toggle: .showHints, title: "Hints", detail: "Show the hint button.")
                    KakuroToggleRow(
                        toggle: .showTutorial, title: "How to play", detail: "Show the ? button with the rules and a walkthrough.")
                    KakuroToggleRow(toggle: .allowReveal, title: "Show solution", detail: "Offer Show solution in the game menu.")
                    if showHints {
                        Toggle(isOn: $hintFill) {
                            VStack(alignment: .leading) {
                                Text("Hints fill the answer in")
                                hint("Off: a hint points at the next step and says why.")
                            }
                        }
                        .tint(accent)
                        .accessibilityIdentifier("setting_hint_fill")
                    }
                }
                .padding(16)
                .modifier(KakuroTileStyle(accent: accent, corner: 12, fill: .clear))
            }
            .padding(16)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func choice(_ options: [(String, String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.1) { title, value, tag in
                let selected = selection.wrappedValue == value
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(selected ? accent.opacity(0.25) : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tag)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.3), lineWidth: 1))
    }
}

private struct KakuroToggleRow: View {
    let toggle: KakuroToggle
    let title: String
    var detail: String?

    @Environment(\.colorScheme) private var scheme
    @AppStorage private var isOn: Bool

    init(toggle: KakuroToggle, title: String, detail: String? = nil) {
        self.toggle = toggle
        self.title = title
        self.detail = detail
        _isOn = AppStorage(wrappedValue: toggle.defaultValue, toggle.key)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
        }
        .tint(KakuroColors.of(scheme).accent)
        .accessibilityIdentifier("setting_\(toggle.rawValue)")
    }
}
