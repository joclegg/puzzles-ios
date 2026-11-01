public enum DailyId {
    public static let prefix = "daily_"

    public static func make(date: CalendarDay, suffix: String) -> String {
        "\(prefix)\(date.isoString)_\(suffix)"
    }

    public static func isDaily(_ id: String) -> Bool {
        id.hasPrefix(prefix)
    }

    public static func isoDate(of id: String) -> String {
        String(id.dropFirst(prefix.count).prefix { $0 != "_" })
    }
}
