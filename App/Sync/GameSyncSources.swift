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
final class GameSyncSource<Record: SyncedRecord>: SyncSource {
    let game: String
    private let context: ModelContext
    private let bridge: SettingsBridge

    init(game: String, context: ModelContext, bridge: SettingsBridge) {
        self.game = game
        self.context = context
        self.bridge = bridge
    }

    private var all: [Record] {
        context.fetchOrEmpty(FetchDescriptor<Record>())
    }

    func changed(since: Int64) -> [SyncRow] {
        all.filter { $0.updatedAt > since }.map { record in
            SyncRow(id: record.uuid, data: record.syncJSON, updatedAt: record.updatedAt)
        }
    }

    func apply(_ row: SyncRow) {
        let records = all
        let local = records.first { $0.uuid == row.id }
        if let local, local.updatedAt >= row.updatedAt {
            return
        }
        let center = SyncCenter.shared
        center.applyingRemote = true
        defer { center.applyingRemote = false }
        if row.deleted {
            if let local {
                context.delete(local)
                context.saveOrReport()
            }
            return
        }
        guard let record = Record.fromSync(SyncFields(json: row.data), uuid: row.id, updatedAt: row.updatedAt, existing: records) else {
            return
        }
        if let local {
            context.delete(local)
        }
        context.insert(record)
        context.saveOrReport()
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
                    ("warnUnwinnable", "warn_unwinnable", false), ("showTimer", "show_timer", true),
                    ("showMoveCount", "show_move_count", true), ("showHints", "show_hints", false),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ]) + [.upper("drawMode", "solitaire_draw_mode", "DRAW_ONE"), .hintFill("solitaire_hint_fill")]
        ),
        SettingsBridge(
            game: "twoTone",
            fields: prefixed(
                "two_tone_",
                [
                    ("markBrokenRules", "mark_broken_rules", false), ("showTimer", "show_timer", true),
                    ("showProgress", "show_progress", false), ("showHints", "show_hints", false),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ]) + [.upper("inputMode", "two_tone_input_mode", "TAP_TO_CYCLE")]
        ),
        SettingsBridge(
            game: "sightlines",
            fields: prefixed(
                "sightlines_",
                [
                    ("markBrokenRules", "mark_broken_rules", false), ("showTimer", "show_timer", true),
                    ("showProgress", "show_progress", false), ("showSeen", "show_seen_count", false),
                    ("showHints", "show_hints", false), ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ]) + [.upper("inputMode", "sightlines_input_mode", "TAP_TO_CYCLE")],
            extraWrite: { json in
                if json["showSeen"] == nil, let value = json["showSeenCount"] as? Bool {
                    UserDefaults.standard.set(value, forKey: SightlinesSettings.showSeenCount)
                }
            }
        ),
        SettingsBridge(
            game: "fiveLetters",
            fields: prefixed(
                "fiveLetters.",
                [
                    ("hardMode", "hard_mode", false), ("highContrast", "high_contrast", false), ("showHints", "show_hints", false),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ])
        ),
        SettingsBridge(
            game: "kakuro",
            fields: prefixed(
                "kakuro_",
                [
                    ("showMistakeCount", "show_mistake_count", false), ("autoRemoveNotes", "auto_remove_notes", false),
                    ("highlightRuns", "highlight_runs", false), ("showTimer", "show_timer", true),
                    ("showCombinations", "show_combinations", false), ("greyUsedDigits", "grey_used_digits", false),
                    ("showHints", "show_hints", false), ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ]) + [
                    .camel("inputMode", "kakuro_input_mode", "cellFirst"), .camel("mistakeCheck", "kakuro_mistake_check", "off"),
                    .hintFill("kakuro_hint_fill"),
                    .camel("combinationOrder", KakuroKeys.combinationOrder, "increasing"),
                ]
        ),
        SettingsBridge(
            game: "slideOut",
            fields: prefixed(
                "slideout_",
                [
                    ("showTimer", "show_timer", true), ("showPar", "show_par", true), ("showHints", "show_hints", false),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ])
        ),
        SettingsBridge(
            game: "wordWheel",
            fields: prefixed(
                "word_wheel_",
                [
                    ("showTimer", "show_timer", true), ("showBonusCount", "show_bonus_count", true), ("showHints", "show_hints", false),
                    ("showTutorial", "show_tutorial", true), ("allowReveal", "allow_reveal", false),
                ])
        ),
    ]

    private static var sudokuBridge: SettingsBridge {
        let assists: [SettingToggle] = [.showHints, .showTutorial, .allowReveal]
        func group(_ mode: GameMode) -> [SettingField] {
            let toggles = SettingToggle.allCases.filter { !assists.contains($0) }.map { toggle in
                SettingField.bool(jsonName(fromEnum: toggle.rawValue), toggle.key(mode), toggle.defaultFor(mode))
            }
            let shared = assists.map { SettingField.bool(jsonName(fromEnum: $0.rawValue), $0.key(mode), $0.defaultFor(mode)) }
            return toggles + shared + [
                .upper("hintStyle", SettingKeys.hintStyle(mode), HintStyle.point.rawValue),
                .upper("mistakeCheck", SettingKeys.mistakes(mode), ModeSettings.defaultMistakeCheck.rawValue),
                .upper("sameNumberStyle", SettingKeys.sameNumber(mode), ModeSettings.defaultHighlightStyle.rawValue),
                .upper("notesStyle", SettingKeys.notes(mode), ModeSettings.defaultHighlightStyle.rawValue),
                .upper("digitCounts", SettingKeys.digitCounts(mode), ModeSettings.defaultDigitCounts.rawValue),
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
                let bests = context.fetchOrEmpty(FetchDescriptor<SudokuPastBestRecord>())
                json["pastBests"] = bests.map { best -> [String: Any] in
                    [
                        "mode": jsonName(fromEnum: best.mode), "difficulty": jsonName(fromEnum: best.difficulty),
                        "bestMs": best.bestMs,
                    ]
                }
            },
            extraWrite: { json in
                for mode in GameMode.allCases {
                    let inner = json[mode == .classic ? "classic" : "killer"] as? [String: Any] ?? [:]
                    for assist in assists {
                        let name = jsonName(fromEnum: assist.rawValue)
                        if inner[name] == nil, let value = json[name] as? Bool {
                            UserDefaults.standard.set(value, forKey: assist.key(mode))
                        }
                    }
                    if inner["hintStyle"] == nil, let value = json["hintStyle"] as? String {
                        UserDefaults.standard.set(enumName(fromJSON: value), forKey: SettingKeys.hintStyle(mode))
                    }
                }
                guard let incoming = json["pastBests"] as? [[String: Any]] else {
                    return
                }
                let context = SudokuStore.shared.context
                let existing = context.fetchOrEmpty(FetchDescriptor<SudokuPastBestRecord>())
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
                context.saveOrReport()
            }
        )
    }

    static func bridge(_ game: String) -> SettingsBridge {
        bridges.first { $0.game == game } ?? SettingsBridge(game: game)
    }

    static let all: [any SyncSource] = Games.all.map { $0.syncSource }
}
