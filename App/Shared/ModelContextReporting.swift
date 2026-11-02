import SwiftData

extension ModelContext {
    func fetchOrEmpty<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
        do {
            return try fetch(descriptor)
        } catch {
            ErrorLog.report(error, "Fetching \(Model.self)")
            return []
        }
    }

    func saveOrReport() {
        do {
            try save()
        } catch {
            ErrorLog.report(error, "Saving")
        }
    }
}
