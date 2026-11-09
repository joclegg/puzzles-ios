import Testing

@testable import PuzzlesSync

struct SyncFixturesTests {
    @Test func fixturePuzzlesAreRecognised() {
        #expect(isFixture(record: ["puzzleId": "fixture_two_tone_duplicate_line"]))
        #expect(isFixture(record: ["puzzleId": "fixture:killer_one_cage"]))
        #expect(isFixture(record: ["wordId": "fixture_word"]))
        #expect(isFixture(record: ["dealId": "fixture_deal"]))
    }

    @Test func realPuzzlesAreNotFixtures() {
        #expect(!isFixture(record: ["puzzleId": "daily_2026-11-09_4"]))
        #expect(!isFixture(record: ["wordId": "daily2_2026-11-09"]))
        #expect(!isFixture(record: [:]))
    }
}
