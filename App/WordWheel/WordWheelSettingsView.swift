import PuzzlesCore
import SwiftUI
import WordWheelEngine

struct WordWheelSettingsView: View {
    @AppStorage(WordWheelSetting.showTimer) private var showTimer = true
    @AppStorage(WordWheelSetting.showBonusCount) private var showBonusCount = true
    @AppStorage(WordWheelSetting.showHints) private var showHints = false
    @AppStorage(WordWheelSetting.showTutorial) private var showTutorial = true
    @AppStorage(WordWheelSetting.allowReveal) private var allowReveal = false

    var body: some View {
        Form {
            row($showTimer, "show_timer", "Show the timer")
            row($showBonusCount, "show_bonus_count", "Show the bonus word count")
            row($showHints, "show_hints", "Hints", detail: "Show the hint button.")
            row(
                $showTutorial,
                "show_tutorial",
                "How to play",
                detail: "Show the ? button with the rules and a walkthrough."
            )
            row($allowReveal, "allow_reveal", "Show solution", detail: "Offer Show solution in the game menu.")
        }
    }

    private func row(_ value: Binding<Bool>, _ tag: String, _ title: String, detail: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: value)
                .labelsHidden()
                .accessibilityIdentifier("setting_\(tag)")
        }
    }
}
