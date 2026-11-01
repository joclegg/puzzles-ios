import PuzzlesCore
import SlideOutEngine
import SwiftData
import SwiftUI

struct SlideOutSettingsView: View {
    let onBack: () -> Void

    @AppStorage(SlideOutSettingKey.showTimer) private var showTimer = true
    @AppStorage(SlideOutSettingKey.showPar) private var showPar = true
    @AppStorage(SlideOutSettingKey.showHints) private var showHints = false
    @AppStorage(SlideOutSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SlideOutSettingKey.allowReveal) private var allowReveal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 12) {
                    row("Show the timer", nil, $showTimer, "setting_show_timer")
                    row("Show par", "The fewest moves the puzzle can be solved in.", $showPar, "setting_show_par")
                    row("Hints", "Show the hint button.", $showHints, "setting_show_hints")
                    row(
                        "How to play",
                        "Show the ? button with the rules and a walkthrough.",
                        $showTutorial,
                        "setting_show_tutorial"
                    )
                    row("Show solution", "Offer Show solution in the game menu.", $allowReveal, "setting_allow_reveal")
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2)))
            }
            .padding(16)
        }
        .slideOutScreen()
    }

    private func row(_ title: String, _ detail: String?, _ value: Binding<Bool>, _ id: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().accessibilityIdentifier(id)
        }
    }
}
