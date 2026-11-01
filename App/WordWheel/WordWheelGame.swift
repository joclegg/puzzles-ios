import PuzzlesCore
import SwiftData
import SwiftUI
import WordWheelEngine

enum WordWheelGame: GameDefinition {
    typealias Record = WordWheelGameEntity

    static let tab = SettingsTab.wordWheel
    static let syncKey = "wordWheel"

    static var context: ModelContext {
        WordWheelRepository.shared.context
    }

    @MainActor
    static let dailies = DailyProvider<Level>(
        tab: .wordWheel, group: { _ in "WORD_WHEEL" }, options: Level.allCases, label: { $0.label },
        tag: { "daily_play_word_wheel_\($0.name.lowercased())" },
        results: {
            WordWheelRepository.shared.history.filter { $0.status == .solved }.compactMap {
                dailyResult(id: $0.ref.id, finishedAt: $0.finishedAt)
            }
        },
        solved: { date in
            let solved = WordWheelRepository.shared.dailySolved(on: date)
            return { solved.contains($0) }
        },
        open: { date, level in
            (try? await WordWheelRepository.shared.openDaily(level, date: date)).map(String.init)
        }
    )

    @MainActor
    static func home() -> AnyView {
        AnyView(WordWheelHomeView())
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
