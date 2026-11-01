import PuzzlesCore
import SwiftData
import SwiftUI

@MainActor
protocol GameDefinition {
    associatedtype DailyOption
    associatedtype Record: SyncedRecord

    static var tab: SettingsTab { get }
    static var syncKey: String { get }
    static var context: ModelContext { get }
    static var dailies: DailyProvider<DailyOption> { get }
    static func home() -> AnyView
    static func fixture(_ name: String) -> AnyView?
}

extension GameDefinition {
    static var dailySource: any DailySource {
        dailies
    }

    static var syncSource: any SyncSource {
        GameSyncSource<Record>(game: syncKey, context: context, bridge: GameSyncSources.bridge(syncKey))
    }
}

@MainActor
enum Games {
    static let all: [any GameDefinition.Type] = [
        SudokuGame.self, SolitaireGame.self, TwoToneGame.self, SightlinesGame.self, FiveLettersGame.self, KakuroGame.self,
        SlideOutGame.self, WordWheelGame.self,
    ]

    static func definition(for tab: SettingsTab) -> any GameDefinition.Type {
        all.first { $0.tab == tab } ?? SudokuGame.self
    }
}

protocol SyncedRecord: PersistentModel {
    var uuid: String { get }
    var updatedAt: Int64 { get }
    var syncJSON: [String: Any] { get }
    static func fromSync(_ fields: SyncFields, uuid: String, updatedAt: Int64, existing: [Self]) -> Self?
}

enum GameClock {
    static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    static func day(of date: Date) -> CalendarDay {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return CalendarDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

extension CalendarDay {
    static var today: CalendarDay {
        GameClock.day(of: Date())
    }
}
