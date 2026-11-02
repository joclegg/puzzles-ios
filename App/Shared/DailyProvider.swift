import PuzzlesCore

@MainActor
protocol DailySource {
    var rules: CalendarRules { get }
    var results: [DailyResult] { get }
    func on(_ date: CalendarDay) -> [GameDaily]
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
        open: @escaping @MainActor (CalendarDay, Option) async -> String?
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
}
