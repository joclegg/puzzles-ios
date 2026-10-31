import FiveLettersEngine
import Foundation
import PuzzlesSync
import SlideOutEngine
import SudokuEngine
import SwiftData
import WordWheelEngine

struct SyncFields {
    let json: [String: Any]

    func string(_ key: String) -> String? {
        json[key] as? String
    }

    func int(_ key: String) -> Int? {
        (json[key] as? NSNumber)?.intValue
    }

    func long(_ key: String) -> Int64? {
        (json[key] as? NSNumber)?.int64Value
    }

    func bool(_ key: String) -> Bool {
        json[key] as? Bool ?? false
    }

    func enumValue(_ key: String) -> String? {
        string(key).map(enumName(fromJSON:))
    }
}

func nullable(_ value: Int64?) -> Any {
    value.map { $0 as Any } ?? NSNull()
}

@MainActor
final class GameSyncSource<Record: PersistentModel>: SyncSource {
    let game: String
    private let context: ModelContext
    private let bridge: SettingsBridge
    private let uuid: (Record) -> String
    private let updatedAt: (Record) -> Int64
    private let toJSON: (Record) -> [String: Any]
    private let make: (SyncFields, String, Int64, [Record]) -> Record?

    init(
        game: String,
        context: ModelContext,
        bridge: SettingsBridge,
        uuid: @escaping (Record) -> String,
        updatedAt: @escaping (Record) -> Int64,
        toJSON: @escaping (Record) -> [String: Any],
        make: @escaping (SyncFields, String, Int64, [Record]) -> Record?
    ) {
        self.game = game
        self.context = context
        self.bridge = bridge
        self.uuid = uuid
        self.updatedAt = updatedAt
        self.toJSON = toJSON
        self.make = make
    }

    private var all: [Record] {
        (try? context.fetch(FetchDescriptor<Record>())) ?? []
    }

    func changed(since: Int64) -> [SyncRow] {
        all.filter { updatedAt($0) > since }.map { record in
            SyncRow(id: uuid(record), data: toJSON(record), updatedAt: updatedAt(record))
        }
    }

    func apply(_ row: SyncRow) {
        let records = all
        let local = records.first { uuid($0) == row.id }
        if let local, updatedAt(local) >= row.updatedAt {
            return
        }
        let center = SyncCenter.shared
        center.applyingRemote = true
        defer { center.applyingRemote = false }
        if row.deleted {
            if let local {
                context.delete(local)
                try? context.save()
            }
            return
        }
        guard let record = make(SyncFields(json: row.data), row.id, row.updatedAt, records) else {
            return
        }
        if let local {
            context.delete(local)
        }
        context.insert(record)
        try? context.save()
    }

    func settings() -> SyncSettings {
        SettingsStamps.stampChanges()
        return SyncSettings(data: bridge.read(), updatedAt: SettingsStamps.updatedAt(game))
    }

    func applySettings(_ settings: SyncSettings) {
        let center = SyncCenter.shared
        center.applyingRemote = true
        defer { center.applyingRemote = false }
        bridge.write(settings.data)
        SettingsStamps.stamp(game, at: settings.updatedAt)
        SettingsStamps.remember(bridge)
    }
}

@MainActor
enum GameSyncSources {
    private static func flags(_ pairs: [(String, String, Bool)]) -> [SettingField] {
        pairs.map { SettingField.bool($0.0, $0.1, $0.2) }
    }

    private static func prefixed(_ prefix: String, _ names: [(String, String, Bool)]) -> [SettingField] {
        names.map { SettingField.bool($0.0, prefix + $0.1, $0.2) }
    }

    static let bridges: [SettingsBridge] = [
        sudokuBridge,
        SettingsBridge(
            game: "solitaire",
            fields: prefixed(
                "solitaire_",
                [
                    ("reverse", "reverse", false), ("oneTapMove", "one_tap_move", true), ("winnableOnly", "winnable_only", true),
                    ("warnUnwinnable", "warn_unwinnable", true), ("showTimer", "show_timer", true),
                    ("showMoveCount", "show_move_count", true), ("showHints", "show_hints", true),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ]) + [.upper("drawMode", "solitaire_draw_mode", "DRAW_ONE"), .hintFill("solitaire_hint_fill")]
        ),
        SettingsBridge(
            game: "twoTone",
            fields: prefixed(
                "two_tone_",
                [
                    ("markBrokenRules", "mark_broken_rules", true), ("showTimer", "show_timer", true),
                    ("showProgress", "show_progress", true), ("showHints", "show_hints", true),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ]) + [.upper("inputMode", "two_tone_input_mode", "TAP_TO_CYCLE")]
        ),
        SettingsBridge(
            game: "sightlines",
            fields: prefixed(
                "sightlines_",
                [
                    ("markBrokenRules", "mark_broken_rules", true), ("showTimer", "show_timer", true),
                    ("showProgress", "show_progress", true), ("showSeenCount", "show_seen_count", true),
                    ("showHints", "show_hints", true), ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ]) + [.upper("inputMode", "sightlines_input_mode", "TAP_TO_CYCLE")]
        ),
        SettingsBridge(
            game: "fiveLetters",
            fields: prefixed(
                "fiveLetters.",
                [
                    ("hardMode", "hard_mode", false), ("highContrast", "high_contrast", false), ("showHints", "show_hints", true),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ])
        ),
        SettingsBridge(
            game: "kakuro",
            fields: prefixed(
                "kakuro_",
                [
                    ("showMistakeCount", "show_mistake_count", true), ("autoRemoveNotes", "auto_remove_notes", true),
                    ("highlightRuns", "highlight_runs", true), ("showTimer", "show_timer", true),
                    ("showCombinations", "show_combinations", false), ("greyUsedDigits", "grey_used_digits", true),
                    ("showHints", "show_hints", true), ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ]) + [
                    .camel("inputMode", "kakuro_input_mode", "cellFirst"), .camel("mistakeCheck", "kakuro_mistake_check", "off"),
                    .hintFill("kakuro_hint_fill"),
                ]
        ),
        SettingsBridge(
            game: "slideOut",
            fields: prefixed(
                "slideout_",
                [
                    ("showTimer", "show_timer", true), ("showPar", "show_par", true), ("showHints", "show_hints", true),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ])
        ),
        SettingsBridge(
            game: "wordWheel",
            fields: prefixed(
                "word_wheel_",
                [
                    ("showTimer", "show_timer", true), ("showBonusCount", "show_bonus_count", true), ("showHints", "show_hints", true),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", true),
                ])
        ),
    ]

    private static var sudokuBridge: SettingsBridge {
        let assists: [SettingToggle] = [.showHints, .showTutorial, .allowReveal]
        func group(_ mode: GameMode) -> [SettingField] {
            let toggles = SettingToggle.allCases.filter { !assists.contains($0) }.map { toggle in
                SettingField.bool(jsonName(fromEnum: toggle.rawValue), toggle.key(mode), toggle.defaultFor(mode))
            }
            return toggles + [
                .upper("mistakeCheck", SettingKeys.mistakes(mode), MistakeCheck.showWrong.rawValue),
                .upper("sameNumberStyle", SettingKeys.sameNumber(mode), HighlightStyle.cell.rawValue),
                .upper("notesStyle", SettingKeys.notes(mode), HighlightStyle.cell.rawValue),
                .upper("digitCounts", SettingKeys.digitCounts(mode), DigitCounts.countUp.rawValue),
            ]
        }
        let top: [SettingField] =
            assists.map { .bool(jsonName(fromEnum: $0.rawValue), $0.key(.classic), $0.defaultFor(.classic)) } + [
                .upper("inputMode", SettingKeys.inputMode, InputMode.cellFirst.rawValue),
                .upper("hintStyle", SettingKeys.hintStyle(.classic), HintStyle.point.rawValue),
            ]
        return SettingsBridge(
            game: "sudoku",
            fields: top,
            nested: [("classic", group(.classic)), ("killer", group(.killer))],
            extraRead: { json in
                let context = SudokuStore.shared.context
                let bests = (try? context.fetch(FetchDescriptor<SudokuPastBestRecord>())) ?? []
                json["pastBests"] = bests.map { best -> [String: Any] in
                    [
                        "mode": jsonName(fromEnum: best.mode), "difficulty": jsonName(fromEnum: best.difficulty),
                        "bestMs": best.bestMs,
                    ]
                }
            },
            extraWrite: { json in
                for mode in GameMode.allCases {
                    for assist in assists {
                        if let value = json[jsonName(fromEnum: assist.rawValue)] as? Bool {
                            UserDefaults.standard.set(value, forKey: assist.key(mode))
                        }
                    }
                    if let value = json["hintStyle"] as? String {
                        UserDefaults.standard.set(enumName(fromJSON: value), forKey: SettingKeys.hintStyle(mode))
                    }
                }
                guard let incoming = json["pastBests"] as? [[String: Any]] else {
                    return
                }
                let context = SudokuStore.shared.context
                let existing = (try? context.fetch(FetchDescriptor<SudokuPastBestRecord>())) ?? []
                for item in incoming {
                    let fields = SyncFields(json: item)
                    guard let mode = fields.enumValue("mode"), let difficulty = fields.enumValue("difficulty"),
                        let bestMs = fields.long("bestMs")
                    else {
                        continue
                    }
                    if let match = existing.first(where: { $0.mode == mode && $0.difficulty == difficulty }) {
                        match.bestMs = bestMs
                    } else {
                        context.insert(SudokuPastBestRecord(mode: mode, difficulty: difficulty, bestMs: bestMs))
                    }
                }
                try? context.save()
            }
        )
    }

    private static func bridge(_ game: String) -> SettingsBridge {
        bridges.first { $0.game == game } ?? SettingsBridge(game: game)
    }

    static let all: [any SyncSource] = [
        GameSyncSource<SudokuGameRecord>(
            game: "sudoku", context: SudokuStore.shared.context, bridge: bridge("sudoku"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                SudokuGameRecord(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<SolitaireGameRecord>(
            game: "solitaire", context: SolitaireStore.shared.context, bridge: bridge("solitaire"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                SolitaireGameRecord(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<TwoToneGameRecord>(
            game: "twoTone", context: TwoToneStore.shared.context, bridge: bridge("twoTone"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                TwoToneGameRecord(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<SightlinesGameRecord>(
            game: "sightlines", context: SightlinesStore.shared.context, bridge: bridge("sightlines"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                SightlinesGameRecord(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<FiveLettersGameRecord>(
            game: "fiveLetters", context: FiveLettersStore.shared.context, bridge: bridge("fiveLetters"), uuid: \.uuid,
            updatedAt: \.updatedAt, toJSON: { $0.syncJSON },
            make: { fields, uuid, at, _ in FiveLettersGameRecord(sync: fields, uuid: uuid, updatedAt: at) }),
        GameSyncSource<KakuroGameEntity>(
            game: "kakuro", context: KakuroStore.shared.context, bridge: bridge("kakuro"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                KakuroGameEntity(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<SlideOutGameRecord>(
            game: "slideOut", context: SlideOutStore.context, bridge: bridge("slideOut"), uuid: \.uuid, updatedAt: \.updatedAt,
            toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                SlideOutGameRecord(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
        GameSyncSource<WordWheelGameEntity>(
            game: "wordWheel", context: WordWheelRepository.shared.context, bridge: bridge("wordWheel"), uuid: \.uuid,
            updatedAt: \.updatedAt, toJSON: { $0.syncJSON },
            make: { fields, uuid, at, records in
                WordWheelGameEntity(sync: fields, id: (records.map(\.id).max() ?? 0) + 1, uuid: uuid, updatedAt: at)
            }),
    ]
}
