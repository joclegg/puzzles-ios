import PuzzlesCore
import SolitaireEngine
import SwiftUI

struct SolitaireSettingsView: View {
    let onBack: () -> Void
    @AppStorage(SolitaireSettingKey.drawMode) private var drawMode = DrawMode.drawOne.storageName
    @AppStorage(SolitaireSettingKey.reverse) private var reverse = false
    @AppStorage(SolitaireSettingKey.oneTapMove) private var oneTapMove = true
    @AppStorage(SolitaireSettingKey.winnableOnly) private var winnableOnly = true
    @AppStorage(SolitaireSettingKey.warnUnwinnable) private var warnUnwinnable = false
    @AppStorage(SolitaireSettingKey.showTimer) private var showTimer = true
    @AppStorage(SolitaireSettingKey.showMoveCount) private var showMoveCount = true
    @AppStorage(SolitaireSettingKey.showHints) private var showHints = false
    @AppStorage(SolitaireSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SolitaireSettingKey.hintFill) private var hintFill = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Play").font(.title2)
                    drawChoice
                    Text("Draw 3 is harder. Applies to new games.").font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
                    row(
                        "Reverse",
                        "Foundations start with kings, columns build up from aces. Applies to new games.",
                        $reverse,
                        tag: "setting_reverse"
                    )
                    row(
                        "One tap to move",
                        "Tapping a card sends it to the best place. Off: tap a card, then where it should go.",
                        $oneTapMove,
                        tag: "setting_one_tap_move"
                    )
                    row(
                        "Winnable deals only", "Every new deal can be won. Applies to new deals.", $winnableOnly,
                        tag: "setting_winnable_only")
                    row(
                        "Tell me when a deal can't be won",
                        "Checks after a full pass through the stock with no move, and offers to undo to the last winnable position.",
                        $warnUnwinnable,
                        tag: "setting_warn_unwinnable"
                    )
                    row("Show the timer", nil, $showTimer, tag: "setting_show_timer")
                    row("Show the move counter", nil, $showMoveCount, tag: "setting_show_move_count")
                    row("Hints", "Show the hint button.", $showHints, tag: "setting_show_hints")
                    row("How to play", "Show the ? button with the rules and a walkthrough.", $showTutorial, tag: "setting_show_tutorial")
                    if showHints {
                        row(
                            "Hints fill the answer in", "Off: a hint points at the next step and says why.", $hintFill,
                            tag: "setting_hint_fill")
                    }
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SolitaireColors.onSurfaceVariant.opacity(0.4), lineWidth: 1))
            }
            .padding(16)
        }
        .solitaireScreen()
    }

    private var drawChoice: some View {
        HStack(spacing: 0) {
            ForEach(DrawMode.allCases, id: \.self) { mode in
                Button {
                    drawMode = mode.storageName
                } label: {
                    Text(mode.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(drawMode == mode.storageName ? SolitaireColors.accent.opacity(0.2) : .clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setting_\(mode.tagName)")
                .accessibilityAddTraits(drawMode == mode.storageName ? .isSelected : [])
            }
        }
        .overlay(Capsule().stroke(SolitaireColors.onSurfaceVariant.opacity(0.5), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func row(_ title: String, _ detail: String?, _ value: Binding<Bool>, tag: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(SolitaireColors.onSurfaceVariant)
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(SolitaireColors.accent)
                .accessibilityIdentifier(tag)
        }
    }
}
