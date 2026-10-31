import AuthenticationServices
import Foundation
import Observation
import PuzzlesSync
import Security
import SwiftData
import UIKit

struct URLSessionHttp: Http {
    func send(method: String, url: String, headers: [String: String], body: String?) async throws -> HttpResponse {
        guard let target = URL(string: url) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: target)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body.map { Data($0.utf8) }
        let (data, response) = try await URLSession.shared.data(for: request)
        return HttpResponse(
            code: (response as? HTTPURLResponse)?.statusCode ?? 0,
            body: String(decoding: data, as: UTF8.self)
        )
    }
}

@MainActor
final class DefaultsSyncStore: SyncStoring {
    private static let prefix = "sync.store."
    private static let keychainAccount = "session"
    private static let keychainService = "com.joclegg.puzzles.sync"

    private let defaults = UserDefaults.standard

    var session: Session? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
                kSecReturnData as String: true,
            ]
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
                return nil
            }
            return try? JSONDecoder().decode(Session.self, from: data)
        }
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
            ]
            SecItemDelete(query as CFDictionary)
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                return
            }
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    var verifier: String? {
        get { defaults.string(forKey: Self.prefix + "verifier") }
        set { defaults.set(newValue, forKey: Self.prefix + "verifier") }
    }

    var pulled: String? {
        get { defaults.string(forKey: Self.prefix + "pulled") }
        set { defaults.set(newValue, forKey: Self.prefix + "pulled") }
    }

    func pushed(_ game: String) -> Int64 {
        Int64(defaults.string(forKey: Self.prefix + "pushed_\(game)") ?? "") ?? 0
    }

    func setPushed(_ game: String, _ at: Int64) {
        defaults.set(String(at), forKey: Self.prefix + "pushed_\(game)")
    }

    func settingsPushed(_ game: String) -> Int64 {
        Int64(defaults.string(forKey: Self.prefix + "settings_pushed_\(game)") ?? "") ?? 0
    }

    func setSettingsPushed(_ game: String, _ at: Int64) {
        defaults.set(String(at), forKey: Self.prefix + "settings_pushed_\(game)")
    }

    func remoteSettings(_ game: String) -> [String: Any] {
        guard let text = defaults.string(forKey: Self.prefix + "remote_settings_\(game)"),
            let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    func setRemoteSettings(_ game: String, _ data: [String: Any]) {
        guard let encoded = try? JSONSerialization.data(withJSONObject: data) else {
            return
        }
        defaults.set(String(decoding: encoded, as: UTF8.self), forKey: Self.prefix + "remote_settings_\(game)")
    }

    func clear() {
        session = nil
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}

@MainActor
@Observable
final class SyncCenter: NSObject {
    static let shared = SyncCenter()

    private(set) var email: String?
    private(set) var signedIn = false

    @ObservationIgnored private let store = DefaultsSyncStore()
    @ObservationIgnored private let http = URLSessionHttp()
    @ObservationIgnored private(set) lazy var auth = SupabaseAuth(store: store, http: http, now: Self.nowMs)
    @ObservationIgnored private lazy var engine = SyncEngine(sources: GameSyncSources.all, auth: auth, store: store, http: http)
    @ObservationIgnored private var saveObserver: NSObjectProtocol?
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var webSession: ASWebAuthenticationSession?
    @ObservationIgnored var applyingRemote = false

    nonisolated static func nowMs() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    func start() {
        refresh()
        SettingsStamps.stampChanges()
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                SyncCenter.shared.scheduleSync()
            }
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SyncCenter.shared.settingsChanged()
            }
        }
        syncNow()
    }

    func syncNow() {
        guard store.session != nil else {
            return
        }
        Task {
            await engine.sync()
            refresh()
        }
    }

    func signIn(provider: SignInProvider) {
        guard let url = URL(string: auth.signInUrl(provider: provider)) else {
            return
        }
        let session = ASWebAuthenticationSession(url: url, callback: .customScheme("com.joclegg.puzzles")) { callback, _ in
            guard let callback else {
                return
            }
            MainActor.assumeIsolated {
                SyncCenter.shared.handle(url: callback)
            }
        }
        session.presentationContextProvider = self
        webSession = session
        session.start()
    }

    func handle(url: URL) {
        guard url.scheme == "com.joclegg.puzzles",
            let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            return
        }
        Task {
            if await auth.complete(code: code) {
                signedInNow()
            }
        }
    }

    func signedInNow() {
        refresh()
        syncNow()
    }

    func signOut() {
        auth.signOut()
        refresh()
    }

    private func refresh() {
        let session = store.session
        signedIn = session != nil
        email = session?.email
    }

    private func settingsChanged() {
        if applyingRemote {
            return
        }
        if SettingsStamps.stampChanges() {
            scheduleSync()
        }
    }

    private func scheduleSync() {
        if applyingRemote || store.session == nil {
            return
        }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                syncNow()
            }
        }
    }
}

extension SyncCenter: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}
