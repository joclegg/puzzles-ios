import PuzzlesCore
import SwiftUI
import TwoToneEngine

struct TwoToneSettingsView: View {
    @AppStorage(TwoToneSettingKey.inputMode) private var inputMode = TwoToneInputMode.tapToCycle
    @AppStorage(TwoToneSettingKey.markBrokenRules) private var markBrokenRules = false
    @AppStorage(TwoToneSettingKey.showTimer) private var showTimer = true
    @AppStorage(TwoToneSettingKey.showProgress) private var showProgress = false
    @AppStorage(TwoToneSettingKey.showHints) private var showHints = false
    @AppStorage(TwoToneSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(TwoToneSettingKey.allowReveal) private var allowReveal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filling in").font(.headline)
                    HStack(spacing: 0) {
                        modeButton("Tap to cycle", TwoToneInputMode.tapToCycle, "setting_tap_to_cycle")
                        modeButton("Pick a colour", TwoToneInputMode.pickColour, "setting_pick_colour")
                    }
                    .clipShape(.capsule)
                    .overlay { Capsule().stroke(.secondary.opacity(0.5)) }
                    Text(
                        "Tap to cycle steps a spot through the colours. Pick a colour shows colour buttons under the board: pick one, then tap spots to fill them."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    toggle(
                        "Mark broken rules", "Outline tiles that make three in a row, overfill a line or copy another line.",
                        "setting_mark_broken_rules", $markBrokenRules)
                    toggle("Show the timer", nil, "setting_show_timer", $showTimer)
                    toggle("Show how much is filled in", nil, "setting_show_progress", $showProgress)
                    toggle("Hints", "Show the hint button.", "setting_show_hints", $showHints)
                    toggle("How to play", "Show the ? button with the rules and a walkthrough.", "setting_show_tutorial", $showTutorial)
                    toggle("Show solution", "Offer Show solution in the game menu.", "setting_allow_reveal", $allowReveal)
                }
                .padding(16)
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.4)) }
            }
            .padding(16)
        }
        .tint(TwoToneColors.accent)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeButton(_ title: String, _ mode: String, _ tag: String) -> some View {
        let selected = inputMode == mode
        return Button {
            inputMode = mode
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(selected ? TwoToneColors.accent.opacity(0.25) : Color.clear)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggle(_ title: String, _ detail: String?, _ tag: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier(tag)
    }
}
