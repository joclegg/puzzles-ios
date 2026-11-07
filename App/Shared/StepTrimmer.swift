import PuzzlesCore
import SwiftData

@ModelActor
actor StepTrimmer {
    func trim<Record: PersistentModel>(
        _ type: Record.Type,
        group: @Sendable (Record) -> String,
        isInProgress: @Sendable (Record) -> Bool,
        endedAt: @Sendable (Record) -> Int64,
        id: @Sendable (Record) -> Int64,
        hasSteps: @Sendable (Record) -> Bool,
        strip: @Sendable (Record, Int64) -> Void
    ) {
        let now = GameClock.nowMs()
        let stale = StepTrim.stale(
            modelContext.fetchOrEmpty(FetchDescriptor<Record>()),
            group: group,
            isInProgress: isInProgress,
            endedAt: endedAt,
            id: id
        )
        for record in stale where hasSteps(record) {
            strip(record, now)
        }
        modelContext.saveOrReport()
    }
}
