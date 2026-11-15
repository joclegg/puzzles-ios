import CryptoKit
import Foundation

actor BankStore {
    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let sha256: String
        }
        let files: [String: Entry]
    }

    static let shared = BankStore()
    private static let parallelDownloads = 6
    private static let baseURL = URL(string: "https://joclegg.github.io/puzzles-data/")!

    private let directory: URL
    private var updating: Task<Void, Error>?
    private var cache: [String: [String]] = [:]
    private var applied: Manifest?

    static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "puzzles-data")

    init(directory: URL = BankStore.defaultDirectory) {
        self.directory = directory
    }

    var isReady: Bool {
        isReady(prefixes: [""])
    }

    func isReady(prefixes: [String]) -> Bool {
        guard let manifest = appliedManifest() else {
            return false
        }
        return manifest.files.keys
            .filter { path in prefixes.contains { path.hasPrefix($0) } }
            .allSatisfy { Self.exists(directory.appending(path: $0)) }
    }

    func ensureReady(prefixes: [String] = [""]) async throws {
        if isReady(prefixes: prefixes) {
            return
        }
        try await refresh()
    }

    func refresh() async throws {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: Self.fixtureBanksKey) {
                return
            }
        #endif
        if let updating {
            return try await updating.value
        }
        let task = Task { try await self.update() }
        updating = task
        defer { updating = nil }
        try await task.value
    }

    private func appliedManifest() -> Manifest? {
        if let applied {
            return applied
        }
        guard let data = try? Data(contentsOf: directory.appending(path: "manifest.json")),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
            return nil
        }
        applied = manifest
        return manifest
    }

    private func update() async throws {
        let (manifestData, _) = try await URLSession.shared.data(from: Self.baseURL.appending(path: "manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        let directory = directory
        let current = appliedManifest()
        let pending = manifest.files
            .filter { path, entry in
                current?.files[path]?.sha256 != entry.sha256 || !Self.exists(directory.appending(path: path))
            }
            .map { (path: $0.key, sha256: $0.value.sha256) }
        if pending.isEmpty && current?.files.keys.sorted() == manifest.files.keys.sorted() {
            return
        }
        defer {
            for file in pending {
                cache[file.path] = nil
            }
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, file) in pending.enumerated() {
                if index >= Self.parallelDownloads {
                    _ = try await group.next()
                }
                group.addTask { try await Self.download(path: file.path, sha256: file.sha256, into: directory) }
            }
            try await group.waitForAll()
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifestData.write(to: directory.appending(path: "manifest.json"), options: .atomic)
        applied = manifest
    }

    func lines(_ path: String, retain: Bool = false) throws -> [String] {
        if let cached = cache[path] {
            return cached
        }
        let text = try String(contentsOf: directory.appending(path: path), encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if retain {
            cache[path] = lines
        }
        return lines
    }

    private static func download(path: String, sha256: String, into directory: URL) async throws {
        let target = directory.appending(path: path)
        if let existing = try? Data(contentsOf: target), Self.hash(existing) == sha256 {
            return
        }
        let (data, _) = try await URLSession.shared.data(from: Self.baseURL.appending(path: path))
        guard Self.hash(data) == sha256 else {
            throw URLError(.cannotDecodeContentData)
        }
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

#if DEBUG
    extension BankStore {
        private struct FixtureEntry: Encodable {
            let sha256: String
            let lines: Int
        }

        static let fixtureBanksKey = "fixture_banks"

        @MainActor
        static func seedFixture(defaults: UserDefaults = .standard, directory: URL = BankStore.defaultDirectory) {
            guard let name = defaults.string(forKey: "fixture") else {
                return
            }
            let files = Games.all.lazy.compactMap { $0.fixtureBank(name) }.first ?? [:]
            do {
                try writeFixture(files, into: directory)
                defaults.set(true, forKey: fixtureBanksKey)
            } catch {
                ErrorLog.report(error, "Fixture banks")
            }
        }

        static func writeFixture(_ files: [String: [String]], into directory: URL) throws {
            let manager = FileManager.default
            if exists(directory) {
                try manager.removeItem(at: directory)
            }
            var entries: [String: FixtureEntry] = [:]
            for (path, lines) in files {
                let data = Data(lines.map { $0 + "\n" }.joined().utf8)
                let target = directory.appending(path: path)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: target, options: .atomic)
                entries[path] = FixtureEntry(sha256: hash(data), lines: lines.count)
            }
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let manifest = try JSONEncoder().encode(["files": entries])
            try manifest.write(to: directory.appending(path: "manifest.json"), options: .atomic)
        }
    }
#endif
