import FiveLettersEngine
import Observation
import SwiftUI

enum FiveLettersDialog {
    case reveal
    case rules
    case walkthrough
}

struct FiveLettersGameView: View {
    let uuid: String

    @State private var model = FiveLettersGameModel()
    @State private var dialog: FiveLettersDialog?
    @State private var settingsOpen = false
    @State private var tour: [String: CGRect] = [:]
    @AppStorage(FiveLettersSetting.showHints.key) private var showHints = FiveLettersSetting.showHints.defaultValue
    @AppStorage(FiveLettersSetting.showTutorial.key) private var showTutorial = FiveLettersSetting.showTutorial.defaultValue
    @AppStorage(FiveLettersSetting.allowReveal.key) private var allowReveal = FiveLettersSetting.allowReveal.defaultValue

    var body: some View {
        Group {
            if let game = model.game {
                content(game)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $settingsOpen) {
            SettingsHubView(initial: .fiveLetters)
        }
        .task {
            if model.game == nil {
                await model.load(uuid: uuid)
            }
        }
    }

    private func content(_ game: GameState) -> some View {
        VStack(spacing: 0) {
            HelpersButton { settingsOpen = true }
            FiveLettersBoard(game: game)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .tourTarget("board", in: $tour)
            Text(model.message)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 20)
                .padding(.vertical, 8)
                .accessibilityIdentifier("message")
            FiveLettersKeyboard(
                letterMarks: game.letterMarks,
                onLetter: model.type,
                onEnter: model.enter,
                onDelete: model.delete
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
            .tourTarget("keyboard", in: $tour)
        }
        .toolbar { toolbar(game) }
        .fullScreenCover(isPresented: coverPresented) {
            cover(game)
                .presentationBackground(.black.opacity(0.4))
        }
        .transaction { $0.disablesAnimations = true }
    }

    @ToolbarContentBuilder
    private func toolbar(_ game: GameState) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.title)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("game_title")
                if game.hardMode {
                    Text("Hard mode").font(.caption2).accessibilityIdentifier("hard_mode")
                }
            }
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItemGroup(placement: .topBarTrailing) {
            if game.isOver {
                ShareLink(item: model.shareText) {
                    Label {
                        Text("Share your result")
                    } icon: {
                        PuzzleIcon.image("square.and.arrow.up")
                    }
                }
                .accessibilityIdentifier("share")
            }
            if showHints {
                Button("Show a hint", systemImage: "lightbulb", action: model.showHint)
                    .disabled(game.isOver)
                    .accessibilityIdentifier("hint")
                    .tourTarget("hint", in: $tour)
            }
            if showTutorial {
                Button("Show the rules", systemImage: "questionmark.circle") {
                    dialog = .rules
                }
                .accessibilityIdentifier("rules")
            }
            Menu {
                if allowReveal && !game.isOver {
                    Button("Show the word") {
                        dialog = .reveal
                    }
                    .accessibilityIdentifier("menu_solution")
                }
                Button("Settings") {
                    settingsOpen = true
                }
                .accessibilityIdentifier("menu_settings")
            } label: {
                Label {
                    Text("More")
                } icon: {
                    PuzzleIcon.image("ellipsis")
                }
            }
            .accessibilityIdentifier("game_menu")
            .tourTarget("menu", in: $tour)
        }
    }

    private var coverPresented: Binding<Bool> {
        Binding(
            get: { dialog != nil || (model.game?.isOver == true && !model.resultClosed) },
            set: { presented in
                if !presented && dialog == nil && model.game?.isOver == true {
                    model.resultClosed = true
                }
            }
        )
    }

    @ViewBuilder
    private func cover(_ game: GameState) -> some View {
        switch dialog {
        case .reveal:
            FiveLettersRevealDialog {
                dialog = nil
            } onConfirm: {
                model.reveal()
                dialog = nil
            }
        case .rules:
            FiveLettersRulesDialog {
                dialog = nil
            } onWalkthrough: {
                dialog = .walkthrough
            }
        case .walkthrough:
            FiveLettersWalkthrough(targets: tour) {
                dialog = nil
            }
        case nil:
            FiveLettersResultDialog(
                game: game,
                isDated: model.isDated,
                shareText: model.shareText
            ) {
                model.resultClosed = true
            } onNewPractice: {
                Task { await model.newPractice() }
            }
        }
    }
}

extension View {
    fileprivate func tourTarget(_ key: String, in targets: Binding<[String: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { frame in
            targets.wrappedValue[key] = frame
        }
    }
}
