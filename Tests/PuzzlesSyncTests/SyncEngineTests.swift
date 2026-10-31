import Foundation
import Testing

@testable import PuzzlesSync

private final class FakeHttp: Http, @unchecked Sendable {
    var sent: [(method: String, url: String, body: String?)] = []
    var savedGames = "[]"
    var settings = "[]"
    var refreshCode = 200

    func send(method: String, url: String, headers: [String: String], body: String?) async throws -> HttpResponse {
        sent.append((method, url, body))
        if url.contains("grant_type=refresh_token") {
            return HttpResponse(code: refreshCode, body: #"{"access_token":"new","refresh_token":"r2","expires_in":3600}"#)
        }
        if method == "GET" {
            return HttpResponse(code: 200, body: url.contains("saved_games") ? savedGames : settings)
        }
        return HttpResponse(code: 201, body: "")
    }
}

@MainActor
private final class FakeStore: SyncStoring {
    var session: Session?
    var verifier: String?
    var pulled: String?
    private var pushedAt: [String: Int64] = [:]
    private var settingsAt: [String: Int64] = [:]
    private var remote: [String: [String: Any]] = [:]

    func pushed(_ game: String) -> Int64 { pushedAt[game] ?? 0 }
    func setPushed(_ game: String, _ at: Int64) { pushedAt[game] = at }
    func settingsPushed(_ game: String) -> Int64 { settingsAt[game] ?? 0 }
    func setSettingsPushed(_ game: String, _ at: Int64) { settingsAt[game] = at }
    func remoteSettings(_ game: String) -> [String: Any] { remote[game] ?? [:] }
    func setRemoteSettings(_ game: String, _ data: [String: Any]) { remote[game] = data }
    func clear() { session = nil }
}

@MainActor
private final class FakeSource: SyncSource {
    let game = "kakuro"
    var rows: [SyncRow] = []
    var applied: [SyncRow] = []
    var local = SyncSettings(data: [:], updatedAt: 0)
    var appliedSettings: SyncSettings?

    func changed(since: Int64) -> [SyncRow] { rows.filter { $0.updatedAt > since } }
    func apply(_ row: SyncRow) { applied.append(row) }
    func settings() -> SyncSettings { local }
    func applySettings(_ settings: SyncSettings) { appliedSettings = settings }
}

@MainActor
struct SyncEngineTests {
    private func make(session: Session?) -> (SyncEngine, FakeHttp, FakeStore, FakeSource, SupabaseAuth) {
        let http = FakeHttp()
        let store = FakeStore()
        store.session = session
        let source = FakeSource()
        let auth = SupabaseAuth(store: store, http: http, now: { 1000 })
        return (SyncEngine(sources: [source], auth: auth, store: store, http: http, retryDelay: .zero), http, store, source, auth)
    }

    private let valid = Session(accessToken: "a", refreshToken: "r", expiresAt: 10_000_000, email: nil)

    @Test("given a changed game when it syncs then it is pushed once and the cursor moves")
    func pushes() async {
        // Arrange
        let (engine, http, store, source, _) = make(session: valid)
        source.rows = [SyncRow(id: "u1", data: ["id": "u1"], updatedAt: 500)]

        // Act
        await engine.sync()
        await engine.sync()

        // Assert
        let posts = http.sent.filter { $0.method == "POST" && $0.url.contains("saved_games") }
        #expect(posts.count == 1)
        #expect(store.pushed("kakuro") == 500)
    }

    @Test("given a remote row when it syncs then the source receives it and the cursor moves")
    func pulls() async {
        // Arrange
        let (engine, http, store, source, _) = make(session: valid)
        http.savedGames =
            #"[{"game":"kakuro","id":"u2","data":{"id":"u2"},"updated_at":"2026-10-31T12:00:00Z","deleted":false,"synced_at":"2026-10-31T12:00:01Z"},"#
            + #"{"game":"other","id":"u3","data":{},"updated_at":"2026-10-31T12:00:00Z","deleted":false,"synced_at":"2026-10-31T12:00:00Z"}]"#

        // Act
        await engine.sync()

        // Assert
        #expect(source.applied.map(\.id) == ["u2"])
        #expect(store.pulled == "2026-10-31T12:00:01Z")
    }

    @Test("given newer remote settings when it syncs then they apply, and older ones do not")
    func settingsLastWriteWins() async {
        // Arrange
        let (engine, http, _, source, _) = make(session: valid)
        http.settings = #"[{"game":"kakuro","data":{"a":true},"updated_at":"2026-10-31T12:00:00Z","synced_at":"2026-10-31T12:00:00Z"}]"#

        // Act
        source.local = SyncSettings(data: [:], updatedAt: 9_000_000_000_000)
        await engine.sync()
        let older = source.appliedSettings
        source.local = SyncSettings(data: [:], updatedAt: 1)
        await engine.sync()

        // Assert
        #expect(older == nil)
        #expect(source.appliedSettings != nil)
    }

    @Test("given a rejected refresh token when a token is needed then the player is signed out")
    func rejectedRefresh() async {
        // Arrange
        let (_, http, store, _, auth) = make(session: Session(accessToken: "a", refreshToken: "r", expiresAt: 0, email: nil))
        http.refreshCode = 400

        // Act
        let token = await auth.accessToken()

        // Assert
        #expect(token == nil)
        #expect(store.session == nil)
    }

    @Test("given an unreachable refresh when a token is needed then the player stays signed in")
    func serverErrorKeepsSession() async {
        // Arrange
        let (_, http, store, _, auth) = make(session: Session(accessToken: "a", refreshToken: "r", expiresAt: 0, email: nil))
        http.refreshCode = 500

        // Act
        let token = await auth.accessToken()

        // Assert
        #expect(token == nil)
        #expect(store.session != nil)
    }

    @Test("given no session when it syncs then nothing is sent")
    func signedOut() async {
        // Arrange
        let (engine, http, _, _, _) = make(session: nil)

        // Act
        let result = await engine.sync()

        // Assert
        #expect(!result)
        #expect(http.sent.isEmpty)
    }
}
