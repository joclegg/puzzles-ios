import PuzzlesCore
import SwiftUI

struct ElapsedTimeText: View {
    let elapsedMs: () -> Int64

    var body: some View {
        Text(formatDuration(elapsedMs()))
    }
}
