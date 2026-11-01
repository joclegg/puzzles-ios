import PuzzlesCore
import SwiftUI

struct GameDaily {
    let tab: SettingsTab
    let group: String
    let label: String
    let tag: String
    let done: Bool
    let offered: Bool
    let calendarLabel: String
    let open: @MainActor () async -> String?

    init(
        tab: SettingsTab,
        group: String,
        label: String,
        tag: String,
        done: Bool,
        offered: Bool,
        calendarLabel: String? = nil,
        open: @escaping @MainActor () async -> String?
    ) {
        self.tab = tab
        self.group = group
        self.label = label
        self.tag = tag
        self.done = done
        self.offered = offered
        self.calendarLabel = calendarLabel ?? label
        self.open = open
    }

    var labelWithGame: String {
        "\(tab.rawValue) \(tab == .sudoku ? calendarLabel : label)"
    }
}

struct DailyLeft: Identifiable {
    let id: String
    let label: String
    let onClick: () -> Void
}

struct CalendarRules {
    let total: Int
    var firstMedal = Medal.bronze
}

enum DailyRoute: Hashable {
    case game(SettingsTab)
    case calendar(SettingsTab)
}

@MainActor
@Observable
final class DailyRouter {
    static let shared = DailyRouter()

    var path: [DailyRoute] = []
    private(set) var generation = 0
    @ObservationIgnored private var pending: [SettingsTab: String] = [:]
    @ObservationIgnored private var opening = false

    func openCalendar(_ tab: SettingsTab) {
        path.append(.calendar(tab))
    }

    func back() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func open(_ daily: GameDaily) {
        guard !opening else {
            return
        }
        opening = true
        Task {
            if let id = await daily.open() {
                pending = [daily.tab: id]
                path = [.game(daily.tab)]
                generation += 1
            }
            opening = false
        }
    }

    func take(_ tab: SettingsTab) -> String? {
        pending.removeValue(forKey: tab)
    }
}

extension SettingsTab {
    static let games = allCases.filter { $0 != .general }

    @MainActor
    func dailies(on date: CalendarDay) -> [GameDaily] {
        switch self {
        case .general, .sudoku:
            SudokuDailies.on(date)
        case .solitaire:
            SolitaireDailies.on(date)
        case .twoTone:
            TwoToneDailies.on(date)
        case .sightlines:
            SightlinesDailies.on(date)
        case .fiveLetters:
            FiveLettersDailies.on(date)
        case .kakuro:
            KakuroDailies.on(date)
        case .slideOut:
            SlideOutDailies.on(date)
        case .wordWheel:
            WordWheelDailies.on(date)
        }
    }

    @MainActor
    var dailyResults: [DailyResult] {
        switch self {
        case .general, .sudoku:
            SudokuDailies.results
        case .solitaire:
            SolitaireDailies.results
        case .twoTone:
            TwoToneDailies.results
        case .sightlines:
            SightlinesDailies.results
        case .fiveLetters:
            FiveLettersDailies.results
        case .kakuro:
            KakuroDailies.results
        case .slideOut:
            SlideOutDailies.results
        case .wordWheel:
            WordWheelDailies.results
        }
    }

    var calendarRules: CalendarRules {
        switch self {
        case .general, .sudoku:
            SudokuDailies.rules
        case .solitaire:
            SolitaireDailies.rules
        case .twoTone:
            TwoToneDailies.rules
        case .sightlines:
            SightlinesDailies.rules
        case .fiveLetters:
            FiveLettersDailies.rules
        case .kakuro:
            KakuroDailies.rules
        case .slideOut:
            SlideOutDailies.rules
        case .wordWheel:
            WordWheelDailies.rules
        }
    }

    @MainActor
    var dailyDayMap: [CalendarDay: DailyDay] {
        let rules = calendarRules
        return dailyDays(results: dailyResults, total: rules.total, firstMedal: rules.firstMedal)
    }
}

enum AllGolds {
    @MainActor
    static var held: Bool {
        SettingsTab.games.allSatisfy { $0.dailyDayMap[.today]?.medal == .gold }
    }
}

enum TodaysDailies {
    @MainActor
    static func left(group: String) -> [DailyLeft] {
        let router = DailyRouter.shared
        let offered = SettingsTab.games.flatMap { $0.dailies(on: .today) }.filter(\.offered)
        let own = offered.filter { $0.group == group }
        return own.map { daily in
            DailyLeft(id: daily.tag, label: daily.label) { router.open(daily) }
        }
    }
}

func dailyResult(id: String, finishedAt: Int64?) -> DailyResult? {
    dailyDate(fromId: id).map { DailyResult(date: $0, id: id, finishedOn: finishedDay(finishedAt)) }
}

func finishedDay(_ finishedAt: Int64?) -> CalendarDay? {
    finishedAt.map { sudokuDay(Date(timeIntervalSince1970: Double($0) / 1000)) }
}
