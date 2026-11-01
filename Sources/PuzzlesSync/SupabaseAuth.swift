import CryptoKit
import Foundation

public enum SupabaseConfig {
    public static let url = "https://nrlmaucpuesfmvqhtupe.supabase.co"
    public static let key = "sb_publishable_gQgbll0ElIbV41OtkvuXlQ_yUegn2hH"
    public static let redirect = "com.joclegg.puzzles://auth"
}

public enum SignInProvider: String, Sendable, CaseIterable {
    case google
    case microsoft = "azure"

    var scopes: String? {
        self == .microsoft ? "email" : nil
    }
}

public struct HttpResponse: Sendable {
    public let code: Int
    public let body: String

    public init(code: Int, body: String) {
        self.code = code
        self.body = body
    }

    public var ok: Bool {
        (200..<300).contains(code)
    }
}

public protocol Http: Sendable {
    func send(method: String, url: String, headers: [String: String], body: String?) async throws -> HttpResponse
}

public struct Session: Equatable, Sendable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Int64
    public let email: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case email
    }

    public init(accessToken: String, refreshToken: String, expiresAt: Int64, email: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.email = email
    }

    public static func fromTokenResponse(_ text: String, now: Int64) -> Session? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
            let access = json["access_token"] as? String,
            let refresh = json["refresh_token"] as? String,
            let expiresIn = (json["expires_in"] as? NSNumber)?.int64Value
        else {
            return nil
        }
        let email = (json["user"] as? [String: Any])?["email"] as? String
        return Session(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: now + expiresIn * 1000,
            email: email?.isEmpty == true ? nil : email
        )
    }
}

@MainActor
public protocol SyncStoring: AnyObject {
    var session: Session? { get set }
    var verifier: String? { get set }
    var pulled: String? { get set }
    func pushed(_ game: String) -> Int64
    func setPushed(_ game: String, _ at: Int64)
    func settingsPushed(_ game: String) -> Int64
    func setSettingsPushed(_ game: String, _ at: Int64)
    func remoteSettings(_ game: String) -> [String: Any]
    func setRemoteSettings(_ game: String, _ data: [String: Any])
    func clear()
}

public enum AuthUrls {
    public static func authorize(provider: SignInProvider, challenge: String) -> String {
        let scopes = provider.scopes.map { "&scopes=\($0)" } ?? ""
        return "\(SupabaseConfig.url)/auth/v1/authorize?provider=\(provider.rawValue)\(scopes)&redirect_to=\(encodedRedirect)"
            + "&code_challenge=\(challenge)&code_challenge_method=s256"
    }

    public static func emailLink() -> String {
        "\(SupabaseConfig.url)/auth/v1/otp?redirect_to=\(encodedRedirect)"
    }

    public static func emailLinkBody(email: String, challenge: String) -> [String: Any] {
        [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "create_user": true,
            "code_challenge": challenge,
            "code_challenge_method": "s256",
        ]
    }

    public static func emailCodeBody(email: String, code: String) -> [String: Any] {
        ["type": "email", "email": email.trimmingCharacters(in: .whitespacesAndNewlines), "token": code]
    }

    public static func challenge(of verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    public static func randomVerifier() -> String {
        var generator = SystemRandomNumberGenerator()
        return base64URL(Data((0..<32).map { _ in UInt8.random(in: 0...255, using: &generator) }))
    }

    private static var encodedRedirect: String {
        "com.joclegg.puzzles%3A%2F%2Fauth"
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
public final class SupabaseAuth {
    public static let emailCodeLength = 8
    private static let refreshMarginMs: Int64 = 60_000
    private static let rejectedCodes: Set<Int> = [400, 401, 403]

    private enum SessionResult {
        case ok
        case rejected
        case unreachable
    }

    private let store: any SyncStoring
    private let http: any Http
    private let now: () -> Int64

    public init(store: any SyncStoring, http: any Http, now: @escaping () -> Int64) {
        self.store = store
        self.http = http
        self.now = now
    }

    public func signInUrl(provider: SignInProvider) -> String {
        let verifier = AuthUrls.randomVerifier()
        store.verifier = verifier
        return AuthUrls.authorize(provider: provider, challenge: AuthUrls.challenge(of: verifier))
    }

    public func sendEmailLink(email: String) async -> Bool {
        let verifier = AuthUrls.randomVerifier()
        store.verifier = verifier
        let body = AuthUrls.emailLinkBody(email: email, challenge: AuthUrls.challenge(of: verifier))
        return await post(AuthUrls.emailLink(), body)?.ok == true
    }

    public func verifyEmailCode(email: String, code: String) async -> Bool {
        let body = AuthUrls.emailCodeBody(email: email, code: code)
        guard let response = await post("\(SupabaseConfig.url)/auth/v1/verify", body), response.ok,
            let session = Session.fromTokenResponse(response.body, now: now())
        else {
            return false
        }
        store.session = session
        return true
    }

    public func complete(code: String) async -> Bool {
        guard let verifier = store.verifier else {
            return false
        }
        return await requestSession(grant: "pkce", body: ["auth_code": code, "code_verifier": verifier]) == .ok
    }

    public func accessToken() async -> String? {
        guard let session = store.session else {
            return nil
        }
        if session.expiresAt - Self.refreshMarginMs > now() {
            return session.accessToken
        }
        switch await requestSession(grant: "refresh_token", body: ["refresh_token": session.refreshToken]) {
        case .ok:
            return store.session?.accessToken
        case .rejected:
            signOut()
            return nil
        case .unreachable:
            return nil
        }
    }

    public func signOut() {
        store.clear()
    }

    public func deleteAccount() async -> Bool {
        guard let token = await accessToken() else {
            return false
        }
        let headers = ["apikey": SupabaseConfig.key, "Authorization": "Bearer \(token)", "Content-Type": "application/json"]
        let response = try? await http.send(
            method: "POST", url: "\(SupabaseConfig.url)/rest/v1/rpc/delete_account", headers: headers, body: "{}")
        return response?.ok == true
    }

    private func requestSession(grant: String, body: [String: Any]) async -> SessionResult {
        let response = await post("\(SupabaseConfig.url)/auth/v1/token?grant_type=\(grant)", body)
        if let response, Self.rejectedCodes.contains(response.code) {
            return .rejected
        }
        guard let response, response.ok, let session = Session.fromTokenResponse(response.body, now: now()) else {
            return .unreachable
        }
        store.session = session
        return .ok
    }

    private func post(_ url: String, _ body: [String: Any]) async -> HttpResponse? {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }
        let headers = ["apikey": SupabaseConfig.key, "Content-Type": "application/json"]
        return try? await http.send(method: "POST", url: url, headers: headers, body: String(decoding: data, as: UTF8.self))
    }
}
