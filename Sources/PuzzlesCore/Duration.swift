public func formatDuration(_ ms: Int64) -> String {
    let total = ms / 1000
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let seconds = total % 60
    let paddedSeconds = seconds < 10 ? "0\(seconds)" : "\(seconds)"
    if hours > 0 {
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hours):\(paddedMinutes):\(paddedSeconds)"
    }
    return "\(minutes):\(paddedSeconds)"
}
