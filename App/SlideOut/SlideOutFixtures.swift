import SlideOutEngine

#if DEBUG
    enum SlideOutFixtures {
        static func puzzle(_ name: String) -> PuzzleRef? {
            switch name {
            case "slide_out_two_moves":
                guard let board = try? Board.decode("202H,033V") else {
                    return nil
                }
                return PuzzleRef(id: "fixture_\(name)", level: .beginner, puzzle: Puzzle(board: board, par: 2))
            default:
                return nil
            }
        }
    }
#endif
