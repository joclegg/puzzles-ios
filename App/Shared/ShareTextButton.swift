import PuzzlesCore
import SwiftUI

struct ShareTextButton: View {
    let text: String
    let tag: String
    var label = "Share"

    var body: some View {
        ShareLink(item: text) {
            PuzzleIcon.image("square.and.arrow.up")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }
}

extension SettingsTab {
    @MainActor
    func dailiesShareText(on date: CalendarDay) -> String? {
        guard let body = dailySource.shareBody(on: date) else {
            return nil
        }
        let medals = dailyDayMap.mapValues(\.medal)
        return PuzzlesCore.dailiesShareText(
            game: rawValue, date: date, medal: medals[date] ?? .none, body: body,
            lastSeven: lastSevenMedals(medals, ending: date))
    }

    @MainActor
    var dailyStreak: DailyStreak {
        PuzzlesCore.dailyStreak(days: Set(dailyResults.filter { $0.finishedOn != nil }.map(\.date)), today: .today)
    }
}
