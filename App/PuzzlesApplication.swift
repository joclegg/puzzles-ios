import SwiftUI

@main
struct PuzzlesApplication: App {
    init() {
        HelperDefaults.preserveForExistingUsers()
        #if DEBUG
            BankStore.seedFixture()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
