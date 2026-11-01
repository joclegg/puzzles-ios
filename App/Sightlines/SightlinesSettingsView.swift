import SwiftUI

enum SightlinesSettings {
    static let inputMode = "sightlines_input_mode"
    static let markBrokenRules = "sightlines_mark_broken_rules"
    static let showTimer = "sightlines_show_timer"
    static let showProgress = "sightlines_show_progress"
    static let showSeenCount = "sightlines_show_seen_count"
    static let showHints = "sightlines_show_hints"
    static let showTutorial = "sightlines_show_tutorial"
    static let allowReveal = "sightlines_allow_reveal"
    static let tapToCycle = "TAP_TO_CYCLE"
    static let pickColour = "PICK_COLOUR"
}

struct SightlinesSettingsView: View {
    @AppStorage(SightlinesSettings.markBrokenRules) private var markBrokenRules = false
    @AppStorage(SightlinesSettings.showTimer) private var showTimer = true
    @AppStorage(SightlinesSettings.showProgress) private var showProgress = false
    @AppStorage(SightlinesSettings.showSeenCount) private var showSeenCount = false
    @AppStorage(SightlinesSettings.showHints) private var showHints = false
    @AppStorage(SightlinesSettings.showTutorial) private var showTutorial = true
    @AppStorage(SightlinesSettings.allowReveal) private var allowReveal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                row(
                    $markBrokenRules,
                    "Mark broken rules",
                    "Outline numbers that see too many or can no longer see enough, and blue dots that can see nothing.",
                    tag: "setting_mark_broken_rules"
                )
                row($showTimer, "Show the timer", nil, tag: "setting_show_timer")
                row($showProgress, "Show how much is filled in", nil, tag: "setting_show_progress")
                row(
                    $showSeenCount,
                    "Show what numbers see now",
                    "A small count on each number of the blue dots it can see so far.",
                    tag: "setting_show_seen_count"
                )
                row($showHints, "Hints", "Show the hint button.", tag: "setting_show_hints")
                row($showTutorial, "How to play", "Show the ? button with the rules and a walkthrough.", tag: "setting_show_tutorial")
                row($allowReveal, "Show solution", "Offer Show solution in the game menu.", tag: "setting_allow_reveal")
            }
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SightlinesColors.tileBorder))
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ value: Binding<Bool>, _ title: String, _ detail: String?, tag: String) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading) {
                Text(title)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .tint(SightlinesColors.accent)
        .accessibilityIdentifier(tag)
    }
}
