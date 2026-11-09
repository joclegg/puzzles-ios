public func isFixture(record json: [String: Any]) -> Bool {
    ["puzzleId", "wordId", "dealId"].contains { key in
        (json[key] as? String)?.hasPrefix("fixture") ?? false
    }
}
