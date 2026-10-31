import Testing

@testable import PuzzlesCore

struct XorWowRandomTests {
    @Test("given seed 5 when ints are drawn then they match puzzles-web")
    func intsMatchWeb() {
        // Arrange
        var random = XorWowRandom(seed: 5)

        // Act
        let values = (0..<5).map { _ in random.nextInt() }

        // Assert
        #expect(values == [-1_350_163_013, -332_731_564, -1_136_814_308, 112_964_028, -189_288_304])
    }

    @Test("given a negative seed when every kind of value is drawn then they match puzzles-web")
    func mixedDrawsMatchWeb() {
        // Arrange
        var random = XorWowRandom(seed: -1_234_567_890_123)

        // Act
        let below = (0..<6).map { _ in random.nextInt(below: 100) }
        let powerOfTwo = random.nextInt(below: 64)
        let long = random.nextLong()
        let double = random.nextDouble()
        let bool = random.nextBool()

        // Assert
        #expect(below == [30, 74, 76, 7, 37, 56])
        #expect(powerOfTwo == 4)
        #expect(long == -4_114_051_603_896_480_532)
        #expect(double == 0.017686432823267095)
        #expect(bool)
    }

    @Test("given an int seed when ints are drawn then they match puzzles-web")
    func intSeedMatchesWeb() {
        // Arrange
        var random = XorWowRandom(intSeed: 42)

        // Act
        let values = (0..<3).map { _ in random.nextInt() }

        // Assert
        #expect(values == [972_016_666, 1_740_578_880, -408_207_414])
    }

    @Test("given a bound of one when a value is drawn then the generator still advances")
    func boundOfOneAdvances() {
        // Arrange
        var drawn = XorWowRandom(seed: 5)
        var expected = XorWowRandom(seed: 5)
        _ = expected.nextInt()

        // Act
        let value = drawn.nextInt(below: 1)

        // Assert
        #expect(value == 0)
        #expect(drawn.nextInt() == expected.nextInt())
    }

    @Test("given the daily seed when 944 items are shuffled then the order matches puzzles-web")
    func shuffleMatchesWeb() {
        // Arrange
        var random = XorWowRandom(seed: 5)

        // Act
        let order = Array(0..<944).shuffled(using: &random)

        // Assert
        #expect(Array(order.prefix(8)) == [811, 531, 384, 751, 597, 672, 716, 921])
        #expect(Array(order.suffix(3)) == [10, 285, 29])
    }
}
