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
    private static let baseURL = URL(string: "https://joclegg.github.io/puzzles-data/")!

    private let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "puzzles-data")) {
        self.directory = directory
    }

    var isReady: Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: "manifest.json").path())
    }

    func update() async throws {
        let (manifestData, _) = try await URLSession.shared.data(from: Self.baseURL.appending(path: "manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        for (path, entry) in manifest.files {
            try await download(path: path, sha256: entry.sha256)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try manifestData.write(to: directory.appending(path: "manifest.json"), options: .atomic)
    }

    func lines(_ path: String) throws -> [String] {
        let text = try String(contentsOf: directory.appending(path: path), encoding: .utf8)
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }

    private func download(path: String, sha256: String) async throws {
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

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
