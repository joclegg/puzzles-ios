import Testing

@testable import SolitaireEngine

private let timelines: [(GameTimer, Int64, Int64)] = [
    (GameTimer(), 5_000, 0),
    (GameTimer().start(nowMs: 1_000), 4_000, 3_000),
    (GameTimer().start(nowMs: 1_000).pause(nowMs: 4_000), 60_000, 3_000),
    (GameTimer().start(nowMs: 1_000).pause(nowMs: 4_000).start(nowMs: 10_000), 12_000, 5_000),
    (GameTimer(accumulatedMs: 90_000).start(nowMs: 0), 1_000, 91_000),
]

struct GameTimerTests {
    @Test("given starts and pauses when elapsed time is read then only running time counts", arguments: timelines)
    func elapsed(timer: GameTimer, readAtMs: Int64, expectedMs: Int64) {
        // Act
        let elapsed = timer.elapsedMs(nowMs: readAtMs)

        // Assert
        #expect(elapsed == expectedMs)
    }
}
