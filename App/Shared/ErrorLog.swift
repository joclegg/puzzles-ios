import OSLog

enum ErrorLog {
    private static let logger = Logger(subsystem: "com.joclegg.puzzles", category: "errors")

    static func report(_ error: any Error, _ context: String) {
        logger.error("\(context, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}

@discardableResult
func attempt<T>(
    _ context: String,
    isolation: isolated (any Actor)? = #isolation,
    _ work: () async throws -> T
) async -> T? {
    do {
        return try await work()
    } catch {
        ErrorLog.report(error, context)
        return nil
    }
}
