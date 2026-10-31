import Testing

@testable import TwoToneEngine

struct GridTests {
    @Test(
        "given a grid when broken tiles are found then only tiles breaking a rule are listed",
        arguments: [
            ("RRR. .... .... ....", [0, 1, 2]),
            ("R... R... R... ....", [0, 4, 8]),
            ("RRBB BBRR RRBB ....", [0, 1, 2, 3, 8, 9, 10, 11]),
            ("RBRR .... .... ....", [0, 2, 3]),
            ("RB.. BR.. .... ....", []),
        ]
    )
    func broken(text: String, broken: [Int]) {
        // Act
        let cells = Grid.parse(size: 4, text: text)!.brokenCells()

        // Assert
        #expect(cells == Set(broken))
    }
}
