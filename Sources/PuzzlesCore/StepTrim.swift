public enum StepTrim {
    public static func stale<Item>(
        _ items: [Item],
        group: (Item) -> String,
        isInProgress: (Item) -> Bool,
        endedAt: (Item) -> Int64,
        id: (Item) -> Int64
    ) -> [Item] {
        var latest: [String: Item] = [:]
        for item in items where !isInProgress(item) {
            let key = group(item)
            if let kept = latest[key], (endedAt(kept), id(kept)) > (endedAt(item), id(item)) {
                continue
            }
            latest[key] = item
        }
        let keep = Set(latest.values.map(id))
        return items.filter { !isInProgress($0) && !keep.contains(id($0)) }
    }
}
