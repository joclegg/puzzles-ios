import Foundation
import Testing

@testable import PuzzlesSync

struct SyncNamesTests {
    @Test(
        "given an enum name when it is converted then it round-trips with the JSON name",
        arguments: [("IN_PROGRESS", "inProgress"), ("WON", "won"), ("DRAW_THREE", "drawThree"), ("TAP_TO_CYCLE", "tapToCycle")]
    )
    func names(enumValue: String, json: String) {
        // Act
        let converted = jsonName(fromEnum: enumValue)

        // Assert
        #expect(converted == json)
        #expect(enumName(fromJSON: json) == enumValue)
    }

    @Test(
        "given a server timestamp when it is parsed then microseconds and offsets are handled",
        arguments: [
            ("2026-10-31T12:00:00+00:00", Int64(1_793_448_000_000)),
            ("2026-10-31T12:00:00.123456+00:00", Int64(1_793_448_000_123)),
            ("2026-10-31T12:00:00.5Z", Int64(1_793_448_000_500)),
        ]
    )
    func timestamps(text: String, expected: Int64) {
        // Act
        let parsed = parseTimestamp(text)

        // Assert
        #expect(parsed == expected)
    }

    @Test("given milliseconds when they are formatted then the time parses back to the same value")
    func format() {
        // Act
        let text = formatTimestamp(1_793_448_000_123)

        // Assert
        #expect(text == "2026-10-31T12:00:00.123Z")
        #expect(parseTimestamp(text) == 1_793_448_000_123)
    }
}

struct AuthUrlTests {
    @Test(
        "given a provider when its sign-in URL is made then it names the provider and its scopes",
        arguments: [(SignInProvider.google, "provider=google"), (SignInProvider.microsoft, "provider=azure&scopes=email")]
    )
    func authorize(provider: SignInProvider, query: String) {
        // Act
        let url = AuthUrls.authorize(provider: provider, challenge: "challenge")

        // Assert
        #expect(
            url == "\(SupabaseConfig.url)/auth/v1/authorize?\(query)&redirect_to=com.joclegg.puzzles%3A%2F%2Fauth"
                + "&code_challenge=challenge&code_challenge_method=s256")
    }

    @Test("given the RFC 7636 verifier when it is hashed then the challenge matches the RFC")
    func challenge() {
        // Act
        let result = AuthUrls.challenge(of: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        // Assert
        #expect(result == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("given an email with spaces when the bodies are made then it is trimmed")
    func bodies() {
        // Act
        let link = AuthUrls.emailLinkBody(email: " a@b.c ", challenge: "x")
        let code = AuthUrls.emailCodeBody(email: " a@b.c ", code: "12345678")

        // Assert
        #expect(link["email"] as? String == "a@b.c")
        #expect(link["create_user"] as? Bool == true)
        #expect(code["type"] as? String == "email")
        #expect(code["token"] as? String == "12345678")
    }
}

@MainActor
struct SyncEngineLogicTests {
    @Test("given no cursor when the pull starts then it starts from the epoch")
    func noCursor() {
        // Act
        let since = SyncEngine.pullSince(cursor: nil)

        // Assert
        #expect(parseTimestamp(since) == 0)
    }

    @Test("given a cursor when the pull starts then it overlaps by a minute")
    func overlap() {
        // Act
        let since = SyncEngine.pullSince(cursor: "2026-10-31T12:01:00Z")

        // Assert
        #expect(parseTimestamp(since) == 1_793_448_000_000)
    }

    @Test("given rows when the cursor moves then it takes the latest synced time")
    func cursorMoves() {
        // Arrange
        let rows: [[String: Any]] = [["synced_at": "2026-10-31T12:00:00Z"], ["synced_at": "2026-10-31T12:05:00Z"]]

        // Act
        let result = SyncEngine.pulledUpTo(cursor: "2026-10-31T12:01:00Z", rows: rows)

        // Assert
        #expect(result == "2026-10-31T12:05:00Z")
    }

    @Test("given remote and local settings when they merge then local wins and unknown remote keys stay")
    func merge() {
        // Act
        let merged = SyncEngine.mergeSettings(remote: ["a": 1, "web": true], local: ["a": 2])

        // Assert
        #expect(merged["a"] as? Int == 2)
        #expect(merged["web"] as? Bool == true)
    }

    @Test("given a token response when it is read then the session expires after its lifetime")
    func session() {
        // Arrange
        let body = #"{"access_token":"a","refresh_token":"r","expires_in":3600,"user":{"email":"x@y.z"}}"#

        // Act
        let session = Session.fromTokenResponse(body, now: 1000)

        // Assert
        #expect(session == Session(accessToken: "a", refreshToken: "r", expiresAt: 3_601_000, email: "x@y.z"))
    }
}
