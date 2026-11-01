import SwiftUI

@main
struct PuzzlesApplication: App {
    init() {
        HelperDefaults.preserveForExistingUsers()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
