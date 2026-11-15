import SlideOutEngine

#if DEBUG
    enum SlideOutFixtures {
        static func bank(_ name: String) -> [String: [String]]? {
            switch name {
            case "slide_out_two_moves":
                [:]
            case "slide_out_daily_beginner":
                ["slideout/beginner.txt": ["4;202H,003H,303V,132H,112H,532H,313V,222V,233V"]]
            case "slide_out_level_easy":
                ["slideout/easy.txt": ["10;202H,023V,322H,152V,302V,522H,132V,312V,422H,042H,342H"]]
            default:
                nil
            }
        }

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
