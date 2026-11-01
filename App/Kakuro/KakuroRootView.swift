import KakuroEngine
import PuzzlesCore
import SwiftUI

enum KakuroRoute {
    case game(KakuroGameModel)
    case stats
    case history
    case settings
}

@MainActor
@Observable
final class KakuroNavigator {
    var path: [KakuroRoute] = []
    private var starting = false

    func back() -> Bool {
        guard !path.isEmpty else {
            return false
        }
        path.removeLast()
        return true
    }

    func home() {
        path = []
    }

    func open(_ game: SavedGame) {
        path = [.game(KakuroGameModel(saved: game))]
    }

    func start(_ ref: PuzzleRef) {
        open(KakuroStore.shared.start(ref: ref))
    }

    func startRandom(size: Int) {
        launch {
            let puzzles = await attempt("Kakuro bank") { try await KakuroBank.puzzles(size: size) } ?? []
            guard !puzzles.isEmpty else {
                return
            }
            self.start(PuzzleRef.random(puzzles: puzzles, size: size, seed: Int64.random(in: .min ... .max)))
        }
    }

    func openDaily(size: Int) {
        let date = CalendarDay.today
        let id = PuzzleRef.dailyId(date: date, size: size)
        if let existing = KakuroStore.shared.inProgress.first(where: { $0.ref.id == id }) {
            open(existing)
            return
        }
        launch {
            let puzzles = await attempt("Kakuro bank") { try await KakuroBank.puzzles(size: size) } ?? []
            guard !puzzles.isEmpty else {
                return
            }
            self.start(PuzzleRef.daily(puzzles: puzzles, date: date, size: size))
        }
    }

    private func launch(_ work: @escaping @MainActor () async -> Void) {
        guard !starting else {
            return
        }
        starting = true
        Task {
            await work()
            starting = false
        }
    }
}

struct KakuroRootView: View {
    let fixture: PuzzleRef?

    @Environment(\.dismiss) private var dismiss
    @State private var navigator = KakuroNavigator()
    @State private var openedFixture = false

    var body: some View {
        ZStack {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            edgeSwipe
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if let id = DailyRouter.shared.take(.kakuro).flatMap(Int64.init), let game = KakuroStore.shared.game(id: id) {
                navigator.open(game)
            }
            guard let fixture, !openedFixture else {
                return
            }
            openedFixture = true
            navigator.start(fixture)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch navigator.path.last {
        case .game(let model):
            KakuroGameView(model: model, navigator: navigator).id(model.saved.id)
        case .stats:
            KakuroStatsView(onBack: back)
        case .history:
            KakuroHistoryView(navigator: navigator, onBack: back)
        case .settings:
            SettingsHubView(initial: .kakuro, onBack: back)
        case nil:
            KakuroHomeView(navigator: navigator, onBack: back)
        }
    }

    private var edgeSwipe: some View {
        HStack {
            Color.clear
                .frame(width: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { drag in
                            if drag.translation.width > 60 {
                                back()
                            }
                        }
                )
            Spacer()
        }
    }

    private func back() {
        if !navigator.back() {
            dismiss()
        }
    }
}
