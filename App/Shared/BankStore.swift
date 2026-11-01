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

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "puzzles-data")) {
        self.directory = directory
    }

    var isReady: Bool {
        isReady(prefixes: [""])
    }

    func isReady(prefixes: [String]) -> Bool {
        seedFromHost()
        let manifestURL = directory.appending(path: "manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
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
        seedFromHost()
        if let updating {
            return try await updating.value
        }
        let task = Task { try await self.update() }
        updating = task
        defer { updating = nil }
        try await task.value
    }

    private func update() async throws {
        let (manifestData, _) = try await URLSession.shared.data(from: Self.baseURL.appending(path: "manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        let directory = directory
        let pending = manifest.files.map { (path: $0.key, sha256: $0.value.sha256) }
        defer { cache = [:] }
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
    }

    func lines(_ path: String) throws -> [String] {
        if let cached = cache[path] {
            return cached
        }
        seedFromHost()
        let text = try String(contentsOf: directory.appending(path: path), encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        cache[path] = lines
        return lines
    }

    private func seedFromHost() {
        #if DEBUG && targetEnvironment(simulator)
            let source = URL(filePath: "/tmp/puzzles-e2e-banks")
            let manager = FileManager.default
            guard Self.exists(source), !Self.exists(directory) else {
                return
            }
            try? manager.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? manager.copyItem(at: source, to: directory)
        #endif
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
