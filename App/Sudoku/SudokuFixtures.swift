#if DEBUG
    import Foundation
    import SudokuEngine

    enum SudokuFixtures {
        static let names: Set<String> = [
            "classic_one_left", "classic_easy", "killer_one_cage", "fast_one_left", "daily_classic_one_left",
            draftName,
        ]
        static let draftName = "classic_easy_missing_r1c1"

        private static let givens = digits("530070000600195000098000060800060003400803001700020006060000280000419005000080079")
        private static let solution = digits("534678912672195348198342567859761423426853791713924856961537284287419635345286179")
        private static let fastSolution = digits("123456456123231564564231312645645312")

        static var draft: String {
            "CLASSIC#" + PuzzleCodec.encode(Puzzle(givens: blank(givens, [0]), solution: nil))
        }

        static func puzzle(_ name: String, today: CalendarDayToday = .init()) -> PuzzleRef? {
            switch name {
            case "classic_one_left":
                return ref(name, .classic, blank(solution, [2]))
            case "classic_easy":
                return ref(name, .classic, givens)
            case "killer_one_cage":
                return ref(name, .killer, blank(solution, [0, 1]), rowPairCages)
            case "fast_one_left":
                return PuzzleRef(
                    id: "fixture:\(name)", mode: .classic, difficulty: .fast,
                    puzzle: Puzzle(givens: blank(fastSolution, [2]), solution: fastSolution))
            case "daily_classic_one_left":
                var made = ref(name, .classic, blank(solution, [2]))
                made.id = DailyIds.of(mode: .classic, difficulty: .easy, date: today.day)
                return made
            default:
                return nil
            }
        }

        private static var rowPairCages: [Cage] {
            (0..<9).flatMap { row -> [[Int]] in
                [0, 2, 4, 6].map { col in [row * 9 + col, row * 9 + col + 1] } + [[row * 9 + 8]]
            }.map { cells in Cage(cells: cells, sum: cells.reduce(0) { $0 + solution[$1] }) }
        }

        private static func ref(_ name: String, _ mode: GameMode, _ values: [Int], _ cages: [Cage] = []) -> PuzzleRef {
            PuzzleRef(
                id: "fixture:\(name)", mode: mode, difficulty: .easy,
                puzzle: Puzzle(givens: values, solution: solution, cages: cages))
        }

        private static func digits(_ text: String) -> [Int] {
            text.compactMap(\.wholeNumberValue)
        }

        private static func blank(_ values: [Int], _ cells: Set<Int>) -> [Int] {
            values.indices.map { cells.contains($0) ? 0 : values[$0] }
        }
    }

    struct CalendarDayToday {
        let day = CalendarDay.today
    }
#endif
