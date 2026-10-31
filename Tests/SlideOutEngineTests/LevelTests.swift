import Testing

@testable import SlideOutEngine

struct LevelTests {
    @Test(
        "given a saved level name when it is read then retired levels become Expert",
        arguments: [("HARD", Level.hard), ("EXPERT", Level.expert), ("EVIL", Level.expert)]
    )
    func named(name: String, expected: Level) {
        // Act
        let level = Level.named(name)

        // Assert
        #expect(level == expected)
    }

    @Test(
        "given a synced size when it is read then retired levels become Expert",
        arguments: [(0, Level.beginner), (4, Level.expert), (5, Level.expert)]
    )
    func atSize(size: Int, expected: Level) {
        // Act
        let level = Level.atSize(size)

        // Assert
        #expect(level == expected)
    }
}
