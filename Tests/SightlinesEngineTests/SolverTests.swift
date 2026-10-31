import Testing

@testable import SightlinesEngine

struct SolverTests {
    @Test(
        "given a grid when the next deduction is found then it names the dots and the rule",
        arguments: [
            ("BB.. .... .... ....", [0: 1], Deduction(cells: [4, 2], dot: .red, reason: .satisfied, source: 0)),
            ("B.B. B... .... ....", [0: 2], Deduction(cells: [1], dot: .red, reason: .tooMany, source: 0)),
            ("B... R... .... ....", [0: 3], Deduction(cells: [1], dot: .blue, reason: .needs, source: 0)),
            (".R.. R... .... ....", [:], Deduction(cells: [0], dot: .red, reason: .alone, source: 0)),
        ] as [(String, [Int: Int], Deduction)]
    )
    func deductions(text: String, numbers: [Int: Int], expected: Deduction) {
        // Act
        let deduction = Solver.next(Grid.parse(size: 4, text: text)!, numbers: numbers)

        // Assert
        #expect(deduction == expected)
    }
}
