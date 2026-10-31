#if DEBUG
    enum SlideOutFixtures {
        static func puzzle(_ name: String) -> SlideOutPuzzleRef? {
            switch name {
            case "slide_out_two_moves":
                guard let board = try? SlideOutBoard.decode("202H,033V") else {
                    return nil
                }
                return SlideOutPuzzleRef(id: "fixture_\(name)", level: .beginner, puzzle: SlideOutPuzzle(board: board, par: 2))
            default:
                return nil
            }
        }
    }
#endif
