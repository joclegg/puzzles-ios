import Foundation

public struct SyncRow {
    public let id: String
    public let data: [String: Any]
    public let updatedAt: Int64
    public let deleted: Bool

    public init(id: String, data: [String: Any], updatedAt: Int64, deleted: Bool = false) {
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
        self.deleted = deleted
    }
}

public struct SyncSettings {
    public let data: [String: Any]
    public let updatedAt: Int64

    public init(data: [String: Any], updatedAt: Int64) {
        self.data = data
        self.updatedAt = updatedAt
    }
}

@MainActor
public protocol SyncSource {
    var game: String { get }
    func changed(since: Int64) -> [SyncRow]
    func apply(_ row: SyncRow)
    func settings() -> SyncSettings
    func applySettings(_ settings: SyncSettings)
}

@MainActor
public final class SyncEngine {
    public static let pageSize = 1000
    private static let attempts = 3
    private static let pullOverlapMs: Int64 = 60_000

    private let sources: [any SyncSource]
    private let auth: SupabaseAuth
    private let store: any SyncStoring
    private let http: any Http
    private let retryDelay: Duration
    private var running = false
    private var again = false

    public init(
        sources: [any SyncSource], auth: SupabaseAuth, store: any SyncStoring, http: any Http, retryDelay: Duration = .seconds(30)
    ) {
        self.sources = sources
        self.auth = auth
        self.store = store
        self.http = http
        self.retryDelay = retryDelay
    }

    @discardableResult
    public func sync() async -> Bool {
        if running {
            again = true
            return false
        }
        running = true
        defer { running = false }
        var result = await attempt()
        while again {
            again = false
            result = await attempt()
        }
        return result
    }

    public static func pullSince(cursor: String?) -> String {
        guard let cursor, let at = parseTimestamp(cursor) else {
            return formatTimestamp(0)
        }
        return formatTimestamp(at - pullOverlapMs)
    }

    public static func pulledUpTo(cursor: String?, rows: [[String: Any]]) -> String? {
        let candidates = rows.compactMap { $0["synced_at"] as? String } + (cursor.map { [$0] } ?? [])
        return candidates.max { (parseTimestamp($0) ?? 0) < (parseTimestamp($1) ?? 0) }
    }

    public static func mergeSettings(remote: [String: Any], local: [String: Any]) -> [String: Any] {
        remote.merging(local) { _, new in new }
    }

    private func attempt() async -> Bool {
        for index in 0..<Self.attempts {
            if (try? await syncAll()) == true {
                return true
            }
            if index < Self.attempts - 1 {
                try? await Task.sleep(for: retryDelay)
            }
        }
        return false
    }

    private func syncAll() async throws -> Bool {
        guard let token = await auth.accessToken() else {
            return false
        }
        for source in sources {
            try await push(source, token: token)
        }
        let cursor = store.pulled
        let since = Self.pullSince(cursor: cursor)
        guard let saved = try await select("saved_games", "game,id,data,updated_at,deleted", since, token),
            let settings = try await select("game_settings", "game,data,updated_at", since, token)
        else {
            return false
        }
        for source in sources {
            pull(source, saved: saved, settings: settings)
        }
        if let upTo = Self.pulledUpTo(cursor: cursor, rows: saved + settings) {
            store.pulled = upTo
        }
        return true
    }

    private func push(_ source: any SyncSource, token: String) async throws {
        let rows = source.changed(since: store.pushed(source.game))
        if !rows.isEmpty {
            let body: [[String: Any]] = rows.map { row in
                [
                    "game": source.game, "id": row.id, "data": row.data,
                    "updated_at": formatTimestamp(row.updatedAt), "deleted": row.deleted,
                ]
            }
            if try await upsert("saved_games", body, token), let latest = rows.map(\.updatedAt).max() {
                store.setPushed(source.game, latest)
            }
        }
        let local = source.settings()
        if local.updatedAt > store.settingsPushed(source.game) {
            let merged = Self.mergeSettings(remote: store.remoteSettings(source.game), local: local.data)
            let body: [[String: Any]] = [["game": source.game, "data": merged, "updated_at": formatTimestamp(local.updatedAt)]]
            if try await upsert("game_settings", body, token) {
                store.setSettingsPushed(source.game, local.updatedAt)
                store.setRemoteSettings(source.game, merged)
            }
        }
    }

    private func pull(_ source: any SyncSource, saved: [[String: Any]], settings: [[String: Any]]) {
        for row in saved where row["game"] as? String == source.game {
            guard let id = row["id"] as? String, let data = row["data"] as? [String: Any],
                let stamp = row["updated_at"] as? String, let at = parseTimestamp(stamp)
            else {
                continue
            }
            source.apply(SyncRow(id: id, data: data, updatedAt: at, deleted: row["deleted"] as? Bool ?? false))
        }
        guard let remote = settings.first(where: { $0["game"] as? String == source.game }),
            let stamp = remote["updated_at"] as? String, let at = parseTimestamp(stamp),
            let data = remote["data"] as? [String: Any]
        else {
            return
        }
        store.setRemoteSettings(source.game, data)
        if at > source.settings().updatedAt {
            source.applySettings(SyncSettings(data: data, updatedAt: at))
            store.setSettingsPushed(source.game, at)
        }
    }

    private func select(_ table: String, _ columns: String, _ since: String, _ token: String) async throws -> [[String: Any]]? {
        var rows: [[String: Any]] = []
        var from = 0
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+:")
        let encoded = since.addingPercentEncoding(withAllowedCharacters: allowed) ?? since
        while true {
            let path =
                "\(table)?select=\(columns),synced_at&synced_at=gt.\(encoded)"
                + "&order=synced_at&offset=\(from)&limit=\(Self.pageSize)"
            let response = try await http.send(
                method: "GET", url: "\(SupabaseConfig.url)/rest/v1/\(path)", headers: headers(token), body: nil)
            guard response.ok,
                let page = try JSONSerialization.jsonObject(with: Data(response.body.utf8)) as? [[String: Any]]
            else {
                return nil
            }
            rows += page
            if page.count < Self.pageSize {
                return rows
            }
            from += Self.pageSize
        }
    }

    private func upsert(_ table: String, _ rows: [[String: Any]], _ token: String) async throws -> Bool {
        let data = try JSONSerialization.data(withJSONObject: rows)
        var all = headers(token)
        all["Content-Type"] = "application/json"
        all["Prefer"] = "resolution=merge-duplicates"
        return try await http.send(
            method: "POST", url: "\(SupabaseConfig.url)/rest/v1/\(table)", headers: all, body: String(decoding: data, as: UTF8.self)
        ).ok
    }

    private func headers(_ token: String) -> [String: String] {
        ["apikey": SupabaseConfig.key, "Authorization": "Bearer \(token)"]
    }
}
