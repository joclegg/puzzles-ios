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

extension GameState {
    public func findHint() -> Hint? {
        let grid = puzzle.grid
        let solution = puzzle.solution
        if let solution, let wrong = values.indices.first(where: { values[$0] != 0 && values[$0] != solution[$0] }) {
            return Hint(cell: wrong, digit: solution[wrong], message: "This cell is wrong.")
        }
        let candidates = values.indices.map { cell -> Int in
            if values[cell] != 0 {
                return 0
            }
            return grid.peers[cell].reduce(grid.allDigits) { $0 & ~digitBit(values[$1]) }
        }
        if let single = candidates.firstIndex(where: { $0.nonzeroBitCount == 1 }) {
            let digit = singleDigit(candidates[single])
            return Hint(cell: single, digit: digit, message: "Only \(digit) fits here.")
        }
        for (name, houses) in [("row", grid.rows), ("column", grid.cols), ("box", grid.boxes)] {
            for house in houses {
                for digit in 1...grid.size {
                    let places = house.filter { candidates[$0] & digitBit(digit) != 0 }
                    if places.count == 1 {
                        return Hint(cell: places[0], digit: digit, message: "\(digit) can only go here in this \(name).")
                    }
                }
            }
        }
        guard let solution, let empty = values.firstIndex(of: 0) else {
            return nil
        }
        return Hint(
            cell: empty,
            digit: solution[empty],
            message: "No cell can be worked out yet, so here is the first empty one."
        )
    }
}
