import SwiftUI

struct RootView: View {
    private enum Phase {
        case loading
        case ready
        case failed
    }

    @State private var phase = Phase.loading

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
        .task { await load() }
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
