@testable import SudokuEngine

let easyGivens = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
let easySolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

func digits(_ text: String) -> [Int] {
    text.compactMap(\.wholeNumberValue)
}

let easyPuzzle = Puzzle(givens: digits(easyGivens), solution: digits(easySolution))
let unverifiedPuzzle = Puzzle(givens: digits(easyGivens), solution: nil)
