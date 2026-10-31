import Foundation

public func jsonName(fromEnum name: String) -> String {
    let parts = name.lowercased().split(separator: "_", omittingEmptySubsequences: false).map(String.init)
    guard let first = parts.first else {
        return ""
    }
    return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}

public func enumName(fromJSON name: String) -> String {
    var result = ""
    for character in name {
        if character.isUppercase {
            result += "_"
        }
        result += character.uppercased()
    }
    return result
}

public func parseTimestamp(_ text: String) -> Int64? {
    var base = text
    var fractionMs: Int64 = 0
    if let dot = text.firstIndex(of: ".") {
        let afterDot = text[text.index(after: dot)...]
        let digits = afterDot.prefix { $0.isNumber }
        let padded = (digits + "000").prefix(3)
        fractionMs = Int64(padded) ?? 0
        base = String(text[..<dot]) + afterDot.dropFirst(digits.count)
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: base) else {
        return nil
    }
    return Int64((date.timeIntervalSince1970 * 1000).rounded()) + fractionMs
}

public func formatTimestamp(_ ms: Int64) -> String {
    let seconds = ms >= 0 ? ms / 1000 : (ms - 999) / 1000
    let fraction = ms - seconds * 1000
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let base = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    if fraction == 0 {
        return base
    }
    let padded = String(fraction + 1000).dropFirst()
    return String(base.dropLast()) + "." + padded + "Z"
}
