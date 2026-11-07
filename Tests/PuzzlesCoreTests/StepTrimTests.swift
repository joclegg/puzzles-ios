import Testing

@testable import PuzzlesCore

struct StepTrimTests {
    private struct Game {
        let id: Int64
        let group: String
        let inProgress: Bool
        let endedAt: Int64
    }

    @Test("given finished games in groups when trimmed then all but the latest of each group are stale")
    func staleGames() {
        // Arrange
        let games = [
            Game(id: 1, group: "easy", inProgress: false, endedAt: 1),
            Game(id: 2, group: "easy", inProgress: false, endedAt: 3),
            Game(id: 3, group: "daily", inProgress: false, endedAt: 2),
            Game(id: 4, group: "daily", inProgress: false, endedAt: 4),
            Game(id: 5, group: "easy", inProgress: true, endedAt: 9),
            Game(id: 6, group: "easy", inProgress: false, endedAt: 3),
        ]

        // Act
        let stale = StepTrim.stale(games, group: \.group, isInProgress: \.inProgress, endedAt: \.endedAt, id: \.id)

        // Assert
        #expect(stale.map(\.id) == [1, 2, 3])
    }
}
