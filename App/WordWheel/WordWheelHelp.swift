import SwiftUI

enum WordWheelHelp {
    static let rules = [
        "Swipe across the letters to make a word, or tap them and press the tick.",
        "Find every word in the crossword. Other real words count as bonus words.",
        "Each letter can be used once per word.",
    ]

    static let tour: [(target: String, text: String)] = [
        ("grid", "Find every word in this crossword."),
        ("wheel", "Swipe across the letters to make a word, or tap them in turn and press the tick."),
        ("hint", "Stuck? The bulb fills in one letter of the crossword."),
        ("menu", "Show the solution and settings live in this menu."),
    ]
}

struct WordWheelWalkthrough: View {
    let index: Int
    let bounds: [String: CGRect]
    let onIndex: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        let steps = WordWheelHelp.tour
        let step = steps[index]
        let last = index == steps.count - 1
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.4)
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
                if let target = bounds[step.target] {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(WheelColors.accent, lineWidth: 4)
                        .frame(width: target.width + 12, height: target.height + 12)
                        .position(x: target.midX - origin.x, y: target.midY - origin.y)
                        .allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step \(index + 1) of \(steps.count)").font(.caption)
                    Text(step.text).accessibilityIdentifier("walkthrough_text")
                    HStack(spacing: 16) {
                        Spacer()
                        Button(last ? "Close" : "Skip", action: onClose)
                            .accessibilityIdentifier("walkthrough_close")
                        if index > 0 {
                            Button("Back") { onIndex(index - 1) }
                                .accessibilityIdentifier("walkthrough_back")
                        }
                        if !last {
                            Button("Next") { onIndex(index + 1) }
                                .accessibilityIdentifier("walkthrough_next")
                        }
                    }
                    .tint(WheelColors.accent)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(16)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("walkthrough")
            }
        }
    }
}
