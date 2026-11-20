import PuzzlesCore

@MainActor
protocol DailySource {
    var rules: CalendarRules { get }
    var results: [DailyResult] { get }
    func on(_ date: CalendarDay) -> [GameDaily]
    func shareBody(on date: CalendarDay) -> [String]?
}

struct DailyProvider<Option>: DailySource {
    let tab: SettingsTab
    let options: [Option]
    let firstMedal: Medal
    let group: @MainActor (Option) -> String
    let label: @MainActor (Option) -> String
    let tag: @MainActor (Option) -> String
    let calendarLabel: @MainActor (Option) -> String?
    let finished: @MainActor () -> [DailyResult]
    let solved: @MainActor (CalendarDay) -> (Option) -> Bool
    let offered: @MainActor (CalendarDay, Option, Bool) -> Bool
    let open: @MainActor (CalendarDay, Option) async -> String?
    let share: (@MainActor (CalendarDay, Option) -> DailyShareEntry)?
    let customShareBody: (@MainActor (CalendarDay) -> [String])?

    init(
        tab: SettingsTab,
        group: @escaping @MainActor (Option) -> String,
        options: [Option],
        firstMedal: Medal = .bronze,
        label: @escaping @MainActor (Option) -> String,
        tag: @escaping @MainActor (Option) -> String,
        calendarLabel: (@MainActor (Option) -> String?)? = nil,
        results: @escaping @MainActor () -> [DailyResult],
        solved: @escaping @MainActor (CalendarDay) -> (Option) -> Bool,
        offered: (@MainActor (CalendarDay, Option, Bool) -> Bool)? = nil,
        open: @escaping @MainActor (CalendarDay, Option) async -> String?,
        share: (@MainActor (CalendarDay, Option) -> DailyShareEntry)? = nil,
        shareBody: (@MainActor (CalendarDay) -> [String])? = nil
    ) {
        self.tab = tab
        self.options = options
        self.firstMedal = firstMedal
        self.group = group
        self.label = label
        self.tag = tag
        self.calendarLabel = calendarLabel ?? { _ in nil }
        self.finished = results
        self.solved = solved
        self.offered = offered ?? { _, _, done in !done }
        self.open = open
        self.share = share
        customShareBody = shareBody
    }

    var rules: CalendarRules {
        CalendarRules(total: options.count, firstMedal: firstMedal)
    }

    @MainActor
    var results: [DailyResult] {
        finished()
    }

    @MainActor
    func on(_ date: CalendarDay) -> [GameDaily] {
        let isSolved = solved(date)
        let open = open
        return options.map { option in
            let done = isSolved(option)
            return GameDaily(
                tab: tab,
                group: group(option),
                label: label(option),
                tag: tag(option),
                done: done,
                offered: offered(date, option, done),
                calendarLabel: calendarLabel(option)
            ) {
                await open(date, option)
            }
        }
    }

    @MainActor
    func shareBody(on date: CalendarDay) -> [String]? {
        if let customShareBody {
            return customShareBody(date)
        }
        guard let share else {
            return nil
        }
        return options.map { dailyShareLine(share(date, $0)) }
    }
}
