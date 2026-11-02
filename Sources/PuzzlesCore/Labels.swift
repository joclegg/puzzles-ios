private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

public func sizeLabel(_ size: Int) -> String {
    "\(size) x \(size)"
}

public func dayMonthLabel(month: Int, day: Int) -> String {
    "\(day) \(monthNames[month - 1])"
}

public func dayMonthLabel(iso: String) -> String {
    let parts = iso.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]), monthNames.indices.contains(month - 1) else {
        return iso
    }
    return dayMonthLabel(month: month, day: day)
}
