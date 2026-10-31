public struct LostMoveSearch: Sendable, Equatable {
    public let winnable: Int
    public let lost: Int

    public init(winnable: Int, lost: Int) {
        self.winnable = winnable
        self.lost = lost
    }

    public var probe: Int? {
        lost - winnable > 1 ? (winnable + lost) / 2 : nil
    }

    public func narrow(probe: Int, verdict: Verdict) -> LostMoveSearch {
        if verdict == .winnable {
            return LostMoveSearch(winnable: probe, lost: lost)
        }
        return LostMoveSearch(winnable: winnable, lost: probe)
    }
}
