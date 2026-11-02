import Testing

@testable import PuzzlesCore

struct GameTimerTests {
    @Test(
        "given starts and pauses when elapsed time is read then only running time counts",
        arguments: [
            (GameTimer(), Int64(5_000), Int64(0)),
            (GameTimer().start(nowMs: 1_000), Int64(4_000), Int64(3_000)),
            (GameTimer().start(nowMs: 1_000).pause(nowMs: 4_000), Int64(60_000), Int64(3_000)),
            (GameTimer().start(nowMs: 1_000).pause(nowMs: 4_000).start(nowMs: 10_000), Int64(12_000), Int64(5_000)),
            (GameTimer(accumulatedMs: 90_000).start(nowMs: 0), Int64(1_000), Int64(91_000)),
        ]
    )
    func elapsed(timer: GameTimer, readAtMs: Int64, expectedMs: Int64) {
        // Act
        let elapsed = timer.elapsedMs(nowMs: readAtMs)

        // Assert
        #expect(elapsed == expectedMs)
    }
}
