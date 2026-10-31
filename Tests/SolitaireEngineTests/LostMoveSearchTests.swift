import Testing

@testable import SolitaireEngine

private let probes: [(Int, Int, Int?)] = [
    (0, 40, 20),
    (10, 13, 11),
    (12, 13, nil),
]

struct LostMoveSearchTests {
    @Test("given a winnable and a lost move when probing then it checks the move between them", arguments: probes)
    func probing(winnable: Int, lost: Int, probe: Int?) {
        // Act
        let next = LostMoveSearch(winnable: winnable, lost: lost).probe

        // Assert
        #expect(next == probe)
    }

    @Test(
        "given a verdict at the probe when narrowing then it keeps a proven range",
        arguments: [
            (Verdict.winnable, 20, 40),
            (Verdict.unwinnable, 0, 20),
            (Verdict.unknown, 0, 20),
        ]
    )
    func narrowing(verdict: Verdict, winnable: Int, lost: Int) {
        // Act
        let narrowed = LostMoveSearch(winnable: 0, lost: 40).narrow(probe: 20, verdict: verdict)

        // Assert
        #expect(narrowed == LostMoveSearch(winnable: winnable, lost: lost))
    }
}
