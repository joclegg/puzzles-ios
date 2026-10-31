import Foundation
import PuzzlesSync

enum SettingField {
    case bool(String, String, Bool)
    case upper(String, String, String)
    case camel(String, String, String)
    case hintFill(String)

    fileprivate func read(_ defaults: UserDefaults, into json: inout [String: Any]) {
        switch self {
        case .bool(let name, let key, let fallback):
            json[name] = defaults.object(forKey: key) as? Bool ?? fallback
        case .upper(let name, let key, let fallback):
            json[name] = jsonName(fromEnum: defaults.string(forKey: key) ?? fallback)
        case .camel(let name, let key, let fallback):
            json[name] = defaults.string(forKey: key) ?? fallback
        case .hintFill(let key):
            json["hintStyle"] = (defaults.object(forKey: key) as? Bool ?? false) ? "fill" : "point"
        }
    }

    fileprivate func write(_ defaults: UserDefaults, from json: [String: Any]) {
        switch self {
        case .bool(let name, let key, _):
            if let value = json[name] as? Bool {
                defaults.set(value, forKey: key)
            }
        case .upper(let name, let key, _):
            if let value = json[name] as? String {
                defaults.set(enumName(fromJSON: value), forKey: key)
            }
        case .camel(let name, let key, _):
            if let value = json[name] as? String {
                defaults.set(value, forKey: key)
            }
        case .hintFill(let key):
            if let value = json["hintStyle"] as? String {
                defaults.set(value == "fill", forKey: key)
            }
        }
    }
}

struct SettingsBridge {
    let game: String
    var fields: [SettingField] = []
    var nested: [(String, [SettingField])] = []
    var extraRead: @MainActor (inout [String: Any]) -> Void = { _ in }
    var extraWrite: @MainActor ([String: Any]) -> Void = { _ in }

    @MainActor
    func read() -> [String: Any] {
        let defaults = UserDefaults.standard
        var json: [String: Any] = [:]
        for field in fields {
            field.read(defaults, into: &json)
        }
        for (name, group) in nested {
            var inner: [String: Any] = [:]
            for field in group {
                field.read(defaults, into: &inner)
            }
            json[name] = inner
        }
        extraRead(&json)
        return json
    }

    @MainActor
    func write(_ json: [String: Any]) {
        let defaults = UserDefaults.standard
        for field in fields {
            field.write(defaults, from: json)
        }
        for (name, group) in nested {
            if let inner = json[name] as? [String: Any] {
                for field in group {
                    field.write(defaults, from: inner)
                }
            }
        }
        extraWrite(json)
    }
}

enum SettingsStamps {
    private static let prefix = "syncstamp."

    static func updatedAt(_ game: String) -> Int64 {
        Int64(UserDefaults.standard.string(forKey: prefix + "at." + game) ?? "") ?? 0
    }

    static func stamp(_ game: String, at: Int64) {
        UserDefaults.standard.set(String(at), forKey: prefix + "at." + game)
    }

    @MainActor
    static func remember(_ bridge: SettingsBridge) {
        UserDefaults.standard.set(snapshot(bridge), forKey: prefix + "snapshot." + bridge.game)
    }

    @MainActor
    @discardableResult
    static func stampChanges() -> Bool {
        var changed = false
        for bridge in GameSyncSources.bridges {
            let key = prefix + "snapshot." + bridge.game
            let now = snapshot(bridge)
            let before = UserDefaults.standard.string(forKey: key)
            if before == now {
                continue
            }
            UserDefaults.standard.set(now, forKey: key)
            if before != nil {
                stamp(bridge.game, at: SyncCenter.nowMs())
                changed = true
            }
        }
        return changed
    }

    @MainActor
    private static func snapshot(_ bridge: SettingsBridge) -> String {
        let data = try? JSONSerialization.data(withJSONObject: bridge.read(), options: .sortedKeys)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
}
