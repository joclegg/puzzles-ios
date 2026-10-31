import FiveLettersEngine
import SwiftUI

private struct FiveLettersDialogCard<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(.rect)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            content
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 28))
                .padding(24)
        }
    }
}

struct FiveLettersRevealDialog: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        FiveLettersDialogCard(onDismiss: onCancel) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Show the word?").font(.title2.bold())
                Text("This ends the game and counts as a loss.")
                HStack(spacing: 16) {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancel_reveal")
                    Button("Show the word", action: onConfirm)
                        .accessibilityIdentifier("confirm_reveal")
                }
            }
            .padding(24)
        }
    }
}

struct FiveLettersRulesDialog: View {
    let onClose: () -> Void
    let onWalkthrough: () -> Void

    private let rules = [
        "Guess the five-letter word in six tries. After each guess the tiles change colour:",
        "Green: right letter, right place.",
        "Yellow: in the word, wrong place.",
        "Grey: not in the word.",
    ]

    var body: some View {
        FiveLettersDialogCard(onDismiss: onClose) {
            VStack(alignment: .leading, spacing: 8) {
                Text("How to play").font(.title2.bold())
                ForEach(rules, id: \.self) { rule in
                    Text(rule)
                }
                HStack(spacing: 16) {
                    Spacer()
                    Button("Walk me through it", action: onWalkthrough)
                        .accessibilityIdentifier("walkthrough_start")
                    Button("Got it", action: onClose)
                        .accessibilityIdentifier("rules_close")
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

struct FiveLettersResultDialog: View {
    let game: GameState
    let isDated: Bool
    let shareText: String
    let onClose: () -> Void
    let onNewPractice: () -> Void

    private let theme = FiveLettersTheme()

    var body: some View {
        WinDialog(
            title: game.resultTitle,
            accent: theme.accent,
            dailyGroup: "FIVE_LETTERS",
            newBest: false,
            stats: [],
            tag: "result_dialog",
            message:
                isDated
                ? "A new word comes tomorrow. Share your grid without giving the word away."
                : "Play another practice word, or share your grid.",
            titleTag: "result_title",
            lost: !game.isWon,
            newLabel: "Word",
            newTag: "result_new_practice",
            onNew: isDated ? nil : onNewPractice,
            onDismiss: onClose
        ) {
            Button("Close", action: onClose)
                .accessibilityIdentifier("result_close")
            ShareLink("Share", item: shareText)
                .labelStyle(.titleOnly)
                .accessibilityIdentifier("result_share")
        }
    }
}

struct FiveLettersWalkthrough: View {
    let targets: [String: CGRect]
    let onClose: () -> Void

    @State private var index = 0

    private let steps = [
        (
            "board",
            "Guess the word in six tries. Green is the right letter in the right place, yellow is in the word but elsewhere, grey is not in it."
        ),
        ("keyboard", "Type with these keys, then press Enter."),
        ("hint", "Stuck? The bulb tells you one letter and where it goes."),
        ("menu", "Show the word and settings live in this menu."),
    ]

    var body: some View {
        let step = steps[index]
        let last = index == steps.count - 1
        ZStack(alignment: .bottom) {
            if let target = targets[step.0] {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint, lineWidth: 4)
                    .frame(width: target.width + 12, height: target.height + 12)
                    .position(x: target.midX, y: target.midY)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(index + 1) of \(steps.count)").font(.caption2)
                Text(step.1).accessibilityIdentifier("walkthrough_text")
                HStack(spacing: 16) {
                    Spacer()
                    Button(last ? "Close" : "Skip", action: onClose)
                        .accessibilityIdentifier("walkthrough_close")
                    if index > 0 {
                        Button("Back") { index -= 1 }
                            .accessibilityIdentifier("walkthrough_back")
                    }
                    if !last {
                        Button("Next") { index += 1 }
                            .accessibilityIdentifier("walkthrough_next")
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
            .padding(16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("walkthrough")
        }
    }
}
