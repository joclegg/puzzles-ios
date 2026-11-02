public struct GameTimer: Sendable, Equatable {
    public var accumulatedMs: Int64
    public var runningSinceMs: Int64?

    public init(accumulatedMs: Int64 = 0, runningSinceMs: Int64? = nil) {
        self.accumulatedMs = accumulatedMs
        self.runningSinceMs = runningSinceMs
    }

    public func start(nowMs: Int64) -> GameTimer {
        if runningSinceMs != nil {
            return self
        }
        return GameTimer(accumulatedMs: accumulatedMs, runningSinceMs: nowMs)
    }

    public func pause(nowMs: Int64) -> GameTimer {
        guard let runningSinceMs else {
            return self
        }
        return GameTimer(accumulatedMs: accumulatedMs + (nowMs - runningSinceMs))
    }

    public func elapsedMs(nowMs: Int64) -> Int64 {
        guard let runningSinceMs else {
            return accumulatedMs
        }
        return accumulatedMs + (nowMs - runningSinceMs)
    }
}
