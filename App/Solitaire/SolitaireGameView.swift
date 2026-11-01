import PuzzlesCore
import SolitaireEngine
import SwiftUI

private struct TourTargetKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct TourStep {
    let target: String
    let text: String
}

extension View {
    fileprivate func tourTarget(_ key: String) -> some View {
        anchorPreference(key: TourTargetKey.self, value: .bounds) { [key: $0] }
    }
}

struct SolitaireGameView: View {
    private static let rules = [
        "Move every card up to the four foundations, Ace to King.",
        "In the columns, build down in alternating colours. Any face-up run can move together.",
        "Only a King can fill an empty column.",
        "Tap a card to send it to the best place, or drag it.",
    ]
    private static let tutorial = [
        TourStep(
            target: "table",
            text:
                "Tap the stock to turn cards over. Build the columns down in alternating colours, and the foundations up from Ace to King."
        ),
        TourStep(target: "hint", text: "Stuck? The bulb suggests a move."),
        TourStep(target: "menu", text: "Restart, deal again and settings live in this menu."),
    ]

    let onOpenGame: (Int64) -> Void
    let onHome: () -> Void

    @State private var model: SolitaireGameModel
    @State private var menuOpen = false
    @State private var rulesOpen = false
    @State private var tourStep: Int?
    @State private var settingsOpen = false
    @State private var onScreen = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SolitaireSettingKey.showTimer) private var showTimer = true
    @AppStorage(SolitaireSettingKey.showMoveCount) private var showMoveCount = true
    @AppStorage(SolitaireSettingKey.showHints) private var showHints = false
    @AppStorage(SolitaireSettingKey.showTutorial) private var showTutorial = true
    @AppStorage(SolitaireSettingKey.oneTapMove) private var oneTapMove = true
    @AppStorage(SolitaireSettingKey.warnUnwinnable) private var warnUnwinnable = false

    init(id: Int64, onOpenGame: @escaping (Int64) -> Void, onHome: @escaping () -> Void) {
        _model = State(initialValue: SolitaireGameModel(id: id))
        self.onOpenGame = onOpenGame
        self.onHome = onHome
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HelpersButton { settingsOpen = true }
            if let state = model.game {
                SolitaireBoardView(model: model, state: state)
                    .tourTarget("table")
            }
            if let message = model.hintMessage {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hint_message")
            }
            if model.canFinish {
                Button(action: model.onFinish) {
                    Text("Finish").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(SolitaireColors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityIdentifier("finish")
            }
        }
        .solitaireScreen()
        .overlay(alignment: .topTrailing) { menu }
        .overlay { dialogs }
        .overlayPreferenceValue(TourTargetKey.self) { anchors in
            tour(anchors)
        }
        .navigationDestination(isPresented: $settingsOpen) {
            SettingsHubView(initial: .solitaire) { settingsOpen = false }
        }
        .onAppear {
            onScreen = true
            model.onVisible()
        }
        .onDisappear {
            onScreen = false
            model.onHidden()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if onScreen {
                    model.onVisible()
                }
            } else {
                model.onHidden()
            }
        }
        .onChange(of: oneTapMove) { model.applyPreferences() }
        .onChange(of: warnUnwinnable) { model.applyPreferences() }
    }

    private var header: some View {
        HStack(spacing: 0) {
            SolitaireBackButton(action: onHome)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.title)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 8) {
                    if showTimer {
                        Text(formatDuration(model.elapsedMs))
                            .monospacedDigit()
                            .accessibilityIdentifier("timer")
                    }
                    if showMoveCount {
                        Text("Moves \(model.moveCount)")
                            .accessibilityIdentifier("move_count")
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            SolitaireIconButton(
                symbol: "arrow.uturn.backward",
                label: "Undo the last move",
                tag: "undo",
                enabled: model.canUndo,
                action: model.onUndo
            )
            if showHints {
                SolitaireIconButton(
                    symbol: "lightbulb",
                    label: "Show a hint",
                    tag: "hint",
                    enabled: !model.isWon,
                    action: model.onHint
                )
                .tourTarget("hint")
            }
            if showTutorial {
                SolitaireIconButton(symbol: "questionmark.circle", label: "Show the rules", tag: "rules") {
                    rulesOpen = true
                }
            }
            SolitaireIconButton(symbol: "ellipsis", label: "More", tag: "game_menu") {
                menuOpen.toggle()
            }
            .tourTarget("menu")
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var menu: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { menuOpen = false }
                VStack(alignment: .leading, spacing: 0) {
                    menuItem("Restart this deal", tag: "restart", enabled: !model.isWon) { model.onRestart() }
                    menuItem("New deal", tag: "new_deal") { newDeal() }
                    menuItem("Settings", tag: "menu_settings") { settingsOpen = true }
                }
                .background(SolitaireColors.tile, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8)
                .frame(maxWidth: 220)
                .padding(.top, 44)
                .padding(.trailing, 8)
            }
        }
    }

    private func menuItem(_ title: String, tag: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            menuOpen = false
            action()
        } label: {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .tint(SolitaireColors.onSurface)
        .accessibilityIdentifier(tag)
    }

    private func newDeal() {
        Task {
            if let id = await model.newDeal() {
                onOpenGame(id)
            }
        }
    }

    @ViewBuilder
    private var dialogs: some View {
        if rulesOpen {
            SolitaireDialog(tag: nil, onDismiss: { rulesOpen = false }) {
                Text("How to play").font(.title2)
                ForEach(Self.rules, id: \.self) { Text($0) }
                HStack {
                    Spacer()
                    SolitaireTextButton(title: "Walk me through it", tag: "walkthrough_start") {
                        rulesOpen = false
                        tourStep = 0
                    }
                    SolitaireTextButton(title: "Got it", tag: "rules_close") { rulesOpen = false }
                }
            }
        }
        if model.showUnwinnable {
            SolitaireDialog(tag: "unwinnable_dialog", onDismiss: model.onDismissUnwinnable) {
                Text("This deal can't be won now").font(.title3.weight(.semibold))
                Text(model.unwinnableText)
                SolitaireTextButton(
                    title: model.undoToWinnableLabel,
                    tag: "undo_to_winnable",
                    enabled: !model.findingLostMove,
                    action: model.onUndoToWinnable
                )
                SolitaireTextButton(title: "Leave as lost", tag: "unwinnable_leave") {
                    model.giveUp()
                    onHome()
                }
                SolitaireTextButton(title: "Keep playing", tag: "keep_playing", action: model.onDismissUnwinnable)
                SolitaireTextButton(title: "New deal", tag: "unwinnable_new_deal") { newDeal() }
            }
        }
        if model.isWon && model.resultSaved {
            WinDialog(
                title: "You won!",
                accent: SolitaireColors.accent,
                dailyGroup: "SOLITAIRE",
                newBest: model.newBest,
                stats: [
                    WinStat(label: "Time", value: formatDuration(model.elapsedMs), tag: "won_time"),
                    WinStat(label: "Moves", value: "\(model.moveCount)", tag: "won_moves"),
                ],
                tag: "won_dialog",
                newLabel: "Deal",
                newTag: "won_new_deal",
                onNew: { newDeal() }
            ) {
                SolitaireTextButton(title: "Home", tag: "won_home", action: onHome)
            }
        }
    }

    @ViewBuilder
    private func tour(_ anchors: [String: Anchor<CGRect>]) -> some View {
        if let index = tourStep {
            let step = Self.tutorial[index]
            let last = index == Self.tutorial.count - 1
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    if let anchor = anchors[step.target] {
                        let rect = proxy[anchor].insetBy(dx: -4, dy: -4)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SolitaireColors.primary, lineWidth: 4)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Step \(index + 1) of \(Self.tutorial.count)").font(.caption)
                        Text(step.text).accessibilityIdentifier("walkthrough_text")
                        HStack {
                            Spacer()
                            SolitaireTextButton(title: last ? "Close" : "Skip", tag: "walkthrough_close") { tourStep = nil }
                            if index > 0 {
                                SolitaireTextButton(title: "Back", tag: "walkthrough_back") { tourStep = index - 1 }
                            }
                            if !last {
                                SolitaireTextButton(title: "Next", tag: "walkthrough_next") { tourStep = index + 1 }
                            }
                        }
                    }
                    .padding(16)
                    .background(SolitaireColors.background, in: RoundedRectangle(cornerRadius: 12))
                    .padding(16)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("walkthrough")
                }
            }
        }
    }
}
