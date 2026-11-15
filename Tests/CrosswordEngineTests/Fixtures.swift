@testable import CrosswordEngine

func puzzle(_ size: Int, _ rows: String) -> Puzzle {
    Puzzle(size: size, solution: Array(rows.filter { !$0.isWhitespace }))
}

let small = puzzle(3, "CAT A#O BOW")

let bankLine =
    "11;MISSTEP#DENE#I#O#Y#R#ORID#OUTCASTM#L#K#H#N##AGED#LOCKETI###S#N###HDEDUCT#ISLE##R#R#N#T#RCHATEAU#AHAO#W#A#T#I#PTEN#MASONRY"
