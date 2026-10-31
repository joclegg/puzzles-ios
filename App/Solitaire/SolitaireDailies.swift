import PuzzlesCore
import SolitaireEngine

enum SolitaireDailies {
    static var rules: CalendarRules {
        CalendarRules(total: 1)
    }

    @MainActor
    static var results: [DailyResult] {
        SolitaireStore.shared.games.filter { $0.status == .won }.compactMap {
            dailyResult(id: $0.deal.id, finishedAt: $0.finishedAt)
        }
    }

    @MainActor
    static func on(_ date: CalendarDay) -> [GameDaily] {
        let store = SolitaireStore.shared
        let id = DealRef.dailyId(date)
        let won = store.dailyWon(id)
        return [
            GameDaily(
                tab: .solitaire, group: "SOLITAIRE", label: "Deal", tag: "daily_play_solitaire", done: won, offered: !won,
                calendarLabel: "Daily deal"
            ) {
                if let existing = store.inProgress.first(where: { $0.deal.id == id }) {
                    return String(existing.id)
                }
                let prefs = SolitairePreferences.current
                let seeds = await SolitaireDealer.winnableSeeds(drawMode: prefs.drawMode, order: prefs.order, enabled: prefs.winnableOnly)
                let deal = DealRef.daily(day: date, drawMode: prefs.drawMode, order: prefs.order, winnableSeeds: seeds)
                return String(store.start(deal).id)
            }
        ]
    }
}
