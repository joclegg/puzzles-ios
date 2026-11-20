import PuzzlesCore
import SwiftData
import SwiftUI
import WordWheelEngine

enum WordWheelGame: GameDefinition {
    typealias Record = WordWheelGameEntity

    static let tab = SettingsTab.wordWheel
    static let syncKey = "wordWheel"

    static var context: ModelContext {
        WordWheelStore.shared.context
    }

    @MainActor
    static let dailies = DailyProvider<Level>(
        tab: .wordWheel, group: { _ in "WORD_WHEEL" }, options: Level.allCases, label: { $0.label },
        tag: { "daily_play_word_wheel_\($0.name.lowercased())" },
        results: {
            WordWheelStore.shared.history.filter { $0.status == .solved }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let solved = WordWheelStore.shared.dailySolved(on: date)
            return { solved.contains($0) }
        },
        open: { date, level in
            await attempt("Word Wheel daily") { try await WordWheelStore.shared.openDaily(level, date: date) }.map(String.init)
        },
        share: { date, level in
            let store = WordWheelStore.shared
            let id = PuzzleRef.dailyId(date: date, level: level)
            return DailyShareEntry(
                label: level.label,
                timeMs: store.history.filter { $0.ref.id == id && $0.status == .solved }.map(\.elapsedMs).min(),
                bestMs: store.stats.first { $0.level == level }?.bestMs
            )
        }
    )

    @MainActor
    static func home() -> AnyView {
        AnyView(WordWheelHomeView())
    }

    static func reloadAfterSync() {
        WordWheelStore.shared.refresh()
    }

    @MainActor
    static func fixtureBank(_ name: String) -> [String: [String]]? {
        #if DEBUG
            return WordWheelFixtures.bank(name)
        #else
            return nil
        #endif
    }

    @MainActor
    static func fixture(_ name: String) -> AnyView? {
        #if DEBUG
            guard let ref = WordWheelFixtures.puzzle(name) else {
                return nil
            }
            return AnyView(WordWheelHomeView(fixture: ref))
        #else
            return nil
        #endif
    }
}

#if DEBUG
    enum WordWheelFixtures {
        static func bank(_ name: String) -> [String: [String]]? {
            switch name {
            case "word_wheel_two_words":
                ["wordwheel/valid.txt": ["CAT"]]
            case "word_wheel_five_letters":
                [
                    "wordwheel/five.txt": ["ERYEV;EVERY@2,0,A|VERY@1,0,D|EVER@2,2,D|YER@0,3,D|EVE@4,2,A|EYE@0,2,A"],
                    "wordwheel/valid.txt": [],
                ]
            case "word_wheel_six_letters":
                [
                    "wordwheel/six.txt": [
                        "EDPARA;PARADE@3,3,A|DRAPE@0,3,D|DARE@1,5,D|AREA@1,8,D|DEAR@1,0,A|READ@2,8,A|PER@0,1,D|ARE@4,1,A"
                    ],
                    "wordwheel/valid.txt": [],
                ]
            default:
                nil
            }
        }

        static func puzzle(_ name: String) -> PuzzleRef? {
            switch name {
            case "word_wheel_two_words":
                guard let crossword = try? Crossword.decode("CRATE@0,0,A|TRACE@0,1,D") else {
                    return nil
                }
                return PuzzleRef(
                    id: "fixture_\(name)",
                    level: .five,
                    puzzle: Puzzle(letters: "TRACE", crossword: crossword)
                )
            default:
                return nil
            }
        }
    }
#endif
