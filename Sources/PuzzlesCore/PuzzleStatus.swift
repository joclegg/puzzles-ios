public enum PuzzleStatus: String, Sendable, CaseIterable {
    case inProgress = "IN_PROGRESS"
    case solved = "SOLVED"
    case abandoned = "ABANDONED"
    case revealed = "REVEALED"

    public var label: String {
        switch self {
        case .inProgress:
            "In progress"
        case .solved:
            "Solved"
        case .abandoned:
            "Abandoned"
        case .revealed:
            "Solution shown"
        }
    }
}
