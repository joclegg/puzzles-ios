import SwiftUI

struct CrosswordSettingsView: View {
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @AppStorage(CrosswordKeys.hintFill) private var hintFill = false
    @AppStorage(CrosswordToggle.showHints.key) private var showHints = CrosswordToggle.showHints.defaultValue

    private var accent: Color {
        CrosswordColors.of(scheme).accent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Typing").font(.headline)
                    CrosswordToggleRow(
                        toggle: .skipFilledCells, title: "Skip filled cells",
                        detail: "When you type, jump over cells that already have a letter.")
                    Text("Helpers").font(.headline)
                    CrosswordToggleRow(toggle: .showMistakes, title: "Show mistakes", detail: "Colour wrong letters red.")
                    CrosswordToggleRow(toggle: .showTimer, title: "Show the timer")
                    CrosswordToggleRow(toggle: .showHints, title: "Hints", detail: "Show the hint button.")
                    CrosswordToggleRow(
                        toggle: .allowReveal, title: "Reveal",
                        detail: "Offer Reveal letter, Reveal word and Reveal puzzle in the game menu.")
                    if showHints {
                        Toggle(isOn: $hintFill) {
                            VStack(alignment: .leading) {
                                Text("Hints fill the answer in")
                                Text("Off: a hint points at the next letter and says why.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(accent)
                        .accessibilityIdentifier("setting_hint_fill")
                    }
                }
                .padding(16)
                .modifier(CrosswordTileStyle(accent: accent, corner: 12, fill: .clear))
            }
            .padding(16)
        }
    }
}

private struct CrosswordToggleRow: View {
    let toggle: CrosswordToggle
    let title: String
    var detail: String?

    @Environment(\.colorScheme) private var scheme
    @AppStorage private var isOn: Bool

    init(toggle: CrosswordToggle, title: String, detail: String? = nil) {
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
        .tint(CrosswordColors.of(scheme).accent)
        .accessibilityIdentifier("setting_\(toggle.rawValue)")
    }
}
