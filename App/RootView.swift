import SudokuEngine
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.theme) private var theme = ThemeMode.system.rawValue

    private var colorScheme: ColorScheme? {
        switch ThemeMode(rawValue: theme) {
        case .light:
            .light
        case .dark:
            .dark
        default:
            nil
        }
    }

    var body: some View {
        LauncherView()
            .preferredColorScheme(colorScheme)
            .task {
                SyncCenter.shared.start()
                Task.detached {
                    do {
                        try await BankStore.shared.refresh()
                    } catch {
                        ErrorLog.report(error, "Bank refresh")
                    }
                }
            }
            .onOpenURL { SyncCenter.shared.handle(url: $0) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .inactive {
                    SyncCenter.shared.syncNow()
                }
            }
    }
}

struct BankGate<Content: View>: View {
    private enum Phase {
        case loading
        case ready
        case failed
    }

    let prefixes: [String]
    @ViewBuilder let content: () -> Content

    @State private var phase = Phase.loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("Downloading puzzles")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("bank_loading")
            case .ready:
                content()
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't download the puzzles", systemImage: "wifi.slash")
                } description: {
                    Text("This game needs one download, then it plays offline.")
                } actions: {
                    Button("Try again") {
                        phase = .loading
                        Task { await load() }
                    }
                    .accessibilityIdentifier("bank_retry")
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard phase != .ready else {
            return
        }
        do {
            try await BankStore.shared.ensureReady(prefixes: prefixes)
            phase = .ready
        } catch {
            phase = .failed
        }
    }
}
