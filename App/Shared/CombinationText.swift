import PuzzlesCore
import SwiftUI

func combinationText(_ line: CombinationLine) -> Text {
    var text = AttributedString(line.header)
    if line.sets.isEmpty {
        text += AttributedString("none fit")
    }
    for (index, digits) in line.sets.enumerated() {
        if index > 0 {
            text += AttributedString("  ")
        }
        for digit in digits {
            var part = AttributedString("\(digit.digit)")
            if digit.placed {
                part.inlinePresentationIntent = .stronglyEmphasized
            }
            text += part
        }
    }
    return Text(text)
}
