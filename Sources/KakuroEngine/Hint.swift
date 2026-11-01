public struct Hint: Sendable, Equatable {
    public let cell: Int
    public let digit: Int
    public let message: String

    public init(cell: Int, digit: Int, message: String) {
        self.cell = cell
        self.digit = digit
        self.message = message
    }
}

private let allDigits = (1...maxDigit).reduce(0) { $0 | Combinations.bit($1) }

extension GameState {
    public func findHint() -> Hint? {
        if let wrong = values.indices.first(where: { values[$0] != 0 && values[$0] != puzzle.solution[$0] }) {
            return Hint(cell: wrong, digit: puzzle.solution[wrong], message: "This cell is wrong.")
        }
        let empty = puzzle.runsOf.keys.filter { values[$0] == 0 }.sorted()
        guard let first = empty.first else {
            return nil
        }
        let candidates = narrowedCandidates(empty: empty)
        if let single = empty.first(where: { candidates[$0].nonzeroBitCount == 1 }) {
            let digit = Combinations.digitsOf(candidates[single])[0]
            return Hint(
                cell: single,
                digit: digit,
                message: "Only \(digit) fits here: \(runNames(cell: single)) leave no other digit."
            )
        }
        for run in puzzle.runs {
            let open = run.cells.filter { values[$0] == 0 }
            for digit in Combinations.digitsOf(neededDigits(run: run)) {
                let places = open.filter { candidates[$0] & Combinations.bit(digit) != 0 }
                if places.count == 1 {
                    return Hint(
                        cell: places[0],
                        digit: digit,
                        message: "Every way to make \(run.label) uses a \(digit), and this is the only cell in it where \(digit) fits."
                    )
                }
            }
        }
        let open = empty.filter { candidates[$0] != 0 }
        let cell = open.min { candidates[$0].nonzeroBitCount < candidates[$1].nonzeroBitCount } ?? first
        let allowed = Combinations.digitsOf(candidates[cell] == 0 ? allDigits : candidates[cell])
        let runs = (puzzle.runsOf[cell] ?? []).sorted { $0.isAcross && !$1.isAcross }
            .map { "\($0.isAcross ? "across" : "down") run (\($0.sum) in \($0.cells.count))" }
            .joined(separator: " and ")
        return Hint(
            cell: cell,
            digit: puzzle.solution[cell],
            message: "This cell's \(runs) only allow \(listDigits(allowed))."
        )
    }

    private func narrowedCandidates(empty: [Int]) -> [Int] {
        var candidates = [Int](repeating: 0, count: values.count)
        for cell in empty {
            candidates[cell] = allDigits
        }
        var changed = true
        while changed {
            changed = false
            for run in puzzle.runs {
                let open = run.cells.filter { values[$0] == 0 }
                if open.isEmpty {
                    continue
                }
                var supported = [Int](repeating: 0, count: open.count)
                let placed = placedMask(run: run)
                for mask in fittingMasks(run: run) {
                    assign(cells: open, candidates: candidates, remaining: mask & ~placed, chosen: []) { digits in
                        for (index, digit) in digits.enumerated() {
                            supported[index] |= Combinations.bit(digit)
                        }
                    }
                }
                for (index, cell) in open.enumerated() {
                    let next = candidates[cell] & supported[index]
                    if next != candidates[cell] {
                        candidates[cell] = next
                        changed = true
                    }
                }
            }
        }
        return candidates
    }

    private func assign(
        cells: [Int],
        candidates: [Int],
        remaining: Int,
        chosen: [Int],
        onFound: ([Int]) -> Void
    ) {
        if chosen.count == cells.count {
            onFound(chosen)
            return
        }
        for digit in Combinations.digitsOf(candidates[cells[chosen.count]] & remaining) {
            assign(
                cells: cells,
                candidates: candidates,
                remaining: remaining & ~Combinations.bit(digit),
                chosen: chosen + [digit],
                onFound: onFound
            )
        }
    }

    private func runNames(cell: Int) -> String {
        (puzzle.runsOf[cell] ?? []).map(\.label).joined(separator: " and ")
    }

    private func placedMask(run: Run) -> Int {
        run.cells.filter { values[$0] != 0 }.reduce(0) { $0 | Combinations.bit(values[$1]) }
    }

    private func fittingMasks(run: Run) -> [Int] {
        let placed = placedMask(run: run)
        return Combinations.masks(length: run.cells.count, sum: run.sum).filter { $0 & placed == placed }
    }

    private func neededDigits(run: Run) -> Int {
        let masks = fittingMasks(run: run)
        if masks.isEmpty {
            return 0
        }
        return masks.reduce(allDigits) { $0 & $1 } & ~placedMask(run: run)
    }
}

private func listDigits(_ digits: [Int]) -> String {
    let words = digits.map(String.init)
    guard let last = words.last, words.count > 1 else {
        return words.first ?? ""
    }
    return words.dropLast().joined(separator: ", ") + " or " + last
}

extension Run {
    fileprivate var label: String {
        "\(sum) in \(cells.count) \(isAcross ? "across" : "down")"
    }
}
