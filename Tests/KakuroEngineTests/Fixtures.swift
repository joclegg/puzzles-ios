@testable import KakuroEngine

func puzzle(_ size: Int, _ rows: String, givens: Set<Int> = []) -> Puzzle {
    let digits = rows.filter { !$0.isWhitespace }.compactMap(\.wholeNumberValue)
    return Puzzle(size: size, solution: digits, givens: givens)
}

let small = puzzle(3, "000 012 034")
