import SudokuEngine
import SwiftUI

struct RootView: View {
    private enum Phase {
        case loading
        case ready
        case failed
    }

    @State private var phase = Phase.loading
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
        Group {
            switch phase {
            case .loading:
                ProgressView("Downloading puzzles")
            case .ready:
                LauncherView()
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't download the puzzles", systemImage: "wifi.slash")
                } description: {
                    Text("Puzzles need one download, then every game plays offline.")
                } actions: {
                    Button("Try again") {
                        phase = .loading
                        Task { await load() }
                    }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .task {
            SyncCenter.shared.start()
            await load()
        }
        .onOpenURL { SyncCenter.shared.handle(url: $0) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .inactive {
                SyncCenter.shared.syncNow()
            }
        }
    }

    private func load() async {
        if await BankStore.shared.isReady {
            phase = .ready
            Task.detached { try? await BankStore.shared.update() }
            return
        }
        do {
            try await BankStore.shared.update()
            phase = .ready
        } catch {
            phase = .failed
        }
    }
}
