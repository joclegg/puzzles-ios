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
    @AppStorage(SightlinesSettings.inputMode) private var inputMode = SightlinesSettings.tapToCycle
    @AppStorage(SightlinesSettings.markBrokenRules) private var markBrokenRules = true
    @AppStorage(SightlinesSettings.showTimer) private var showTimer = true
    @AppStorage(SightlinesSettings.showProgress) private var showProgress = true
    @AppStorage(SightlinesSettings.showSeenCount) private var showSeenCount = true
    @AppStorage(SightlinesSettings.showHints) private var showHints = true
    @AppStorage(SightlinesSettings.showTutorial) private var showTutorial = true
    @AppStorage(SightlinesSettings.allowReveal) private var allowReveal = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Filling in").font(.headline)
                HStack(spacing: 0) {
                    segment("Tap to cycle", SightlinesSettings.tapToCycle, tag: "setting_tap_to_cycle")
                    segment("Pick a colour", SightlinesSettings.pickColour, tag: "setting_pick_colour")
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(SightlinesColors.tileBorder))
                Text(
                    "Tap to cycle steps a spot through the colours. Pick a colour shows colour buttons under the board: "
                        + "pick one, then tap spots to fill them."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func segment(_ title: String, _ value: String, tag: String) -> some View {
        Button {
            inputMode = value
        } label: {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(inputMode == value ? Color(uiColor: .systemBackground) : Color.primary)
                .background(inputMode == value ? SightlinesColors.accent : Color.clear)
        }
        .accessibilityIdentifier(tag)
        .accessibilityAddTraits(inputMode == value ? .isSelected : [])
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
