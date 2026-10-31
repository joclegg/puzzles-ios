import SwiftUI
import WordWheelEngine

struct WordWheelGameView: View {
    let onOpenGame: (Int64) -> Void
    let onHome: () -> Void

    @State private var model: WordWheelGameModel
    @State private var revealing = false
    @State private var showRules = false
    @State private var tourIndex: Int?
    @State private var showSettings = false
    @State private var tourBounds: [String: CGRect] = [:]

    @AppStorage(WordWheelSetting.showTimer) private var showTimer = true
    @AppStorage(WordWheelSetting.showBonusCount) private var showBonusCount = true
    @AppStorage(WordWheelSetting.showHints) private var showHints = true
    @AppStorage(WordWheelSetting.showTutorial) private var showTutorial = true
    @AppStorage(WordWheelSetting.allowReveal) private var allowReveal = true
    @Environment(\.scenePhase) private var scenePhase

    init(id: Int64, onOpenGame: @escaping (Int64) -> Void, onHome: @escaping () -> Void) {
        _model = State(initialValue: WordWheelGameModel(id: id))
        self.onOpenGame = onOpenGame
        self.onHome = onHome
    }

    var body: some View {
        Group {
            if let game = model.game {
                content(game)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSettings) {
            WordWheelSettingsView()
        }
        .task { await model.load() }
        .onAppear { model.onVisible() }
        .onDisappear { model.onHidden() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.onVisible()
            } else {
                model.onHidden()
            }
        }
        .overlay { dialogs }
    }

    private func content(_ game: GameState) -> some View {
        VStack(spacing: 0) {
            header
            WordWheelGrid(
                crossword: game.puzzle.crossword,
                found: model.foundCells,
                hinted: model.hintedCells
            )
            .tourTarget("grid", in: $tourBounds)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Text(model.currentText)
                .font(.system(size: 26, weight: .bold))
                .frame(height: 40)
                .accessibilityIdentifier("current_word")
            HStack(spacing: 8) {
                tool("shuffle", "Shuffle the letters", "shuffle", action: model.shuffle)
                WordWheelLetterWheel(
                    letters: Array(game.wheel),
                    chosen: model.chosen,
                    onChosenChange: model.setChosen,
                    onSwipeEnd: model.submit
                )
                .frame(width: 250, height: 250)
                .tourTarget("wheel", in: $tourBounds)
                VStack {
                    tool("checkmark", "Enter the word", "submit_word", action: model.submit)
                    tool("xmark", "Clear the word", "clear_word", action: model.clear)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.headline)
                    .accessibilityIdentifier("game_title")
                HStack(spacing: 12) {
                    if showTimer {
                        Text(formatDuration(model.elapsedMs))
                            .monospacedDigit()
                            .accessibilityIdentifier("timer")
                    }
                    Text("\(model.wordsLeft) to find")
                        .accessibilityIdentifier("words_left")
                    if showBonusCount {
                        Text("Bonus \(model.game?.bonus.count ?? 0)")
                            .accessibilityIdentifier("bonus_count")
                    }
                }
            }
            Spacer(minLength: 0)
            if showHints {
                tool("lightbulb", "Show a letter", "hint", action: model.hint)
                    .disabled(model.isSolved)
                    .tourTarget("hint", in: $tourBounds)
            }
            if showTutorial {
                tool("questionmark.circle", "Show the rules", "rules") { showRules = true }
            }
            menu.tourTarget("menu", in: $tourBounds)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
    }

    private var menu: some View {
        Menu {
            if allowReveal && !model.isSolved {
                Button("Show solution") { revealing = true }
                    .accessibilityIdentifier("menu_solution")
            }
            Button("Settings") { showSettings = true }
                .accessibilityIdentifier("menu_settings")
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityLabel("More")
        .accessibilityIdentifier("game_menu")
    }

    private func tool(_ icon: String, _ label: String, _ tag: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityLabel(label)
        .accessibilityIdentifier(tag)
    }

    @ViewBuilder
    private var dialogs: some View {
        if revealing {
            WordWheelConfirm(
                title: "Show the solution?",
                message: "This ends the puzzle. It won't count towards best times.",
                confirm: "Show solution",
                confirmTag: "confirm_reveal",
                dismiss: "Cancel",
                onConfirm: {
                    revealing = false
                    model.revealSolution()
                },
                onDismissButton: { revealing = false },
                onCancel: { revealing = false }
            )
        }
        if showRules {
            WordWheelConfirm(
                title: "How to play",
                message: WordWheelHelp.rules.joined(separator: "\n\n"),
                confirm: "Got it",
                confirmTag: "rules_close",
                dismiss: "Walk me through it",
                dismissTag: "walkthrough_start",
                onConfirm: { showRules = false },
                onDismissButton: {
                    showRules = false
                    tourIndex = 0
                },
                onCancel: { showRules = false }
            )
        }
        if let tourIndex {
            WordWheelWalkthrough(
                index: tourIndex,
                bounds: tourBounds,
                onIndex: { self.tourIndex = $0 },
                onClose: { self.tourIndex = nil }
            )
        }
        if model.isSolved && model.resultSaved && !model.revealedAll {
            solvedDialog
        }
    }

    private var solvedDialog: some View {
        WordWheelDialogCard(tag: "solved_dialog", onDismiss: {}) {
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 64, height: 64)
                    .background(WheelColors.accent, in: Circle())
                Text("Solved!").font(.title2.bold())
                if model.newBest {
                    Text("NEW BEST")
                        .font(.caption.bold())
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(WheelColors.accent, in: Capsule())
                        .accessibilityIdentifier("new_best")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [WheelColors.accent.opacity(0.3), WheelColors.accent.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            HStack(spacing: 8) {
                stat("Time", formatDuration(model.elapsedMs))
                stat("Bonus words", "\(model.game?.bonus.count ?? 0)")
            }
            let dailies = dailiesLeft
            if !dailies.isEmpty {
                Text("STILL TO PLAY TODAY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(dailies, id: \.self) { level in
                        dailyChip(level)
                    }
                }
            }
            HStack(spacing: 16) {
                Spacer()
                Button("Home", action: onHome)
                    .accessibilityIdentifier("solved_home")
                Button("Next puzzle") {
                    Task { onOpenGame(await model.newPuzzle()) }
                }
                .accessibilityIdentifier("solved_new_puzzle")
            }
            .tint(WheelColors.accent)
        }
    }

    private var dailiesLeft: [Level] {
        let solved = WordWheelRepository.shared.dailySolved(on: WordWheelDates.today)
        return Level.allCases.filter { !solved.contains($0) }
    }

    private func dailyChip(_ level: Level) -> some View {
        Button {
            Task {
                if let id = try? await WordWheelRepository.shared.openDaily(level) {
                    onOpenGame(id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(level.label).font(.caption.weight(.medium))
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(WheelColors.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(WheelColors.accent.opacity(0.15), in: Capsule())
            .overlay { Capsule().stroke(WheelColors.accent.opacity(0.35), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(WheelColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct WordWheelGrid: View {
    let crossword: Crossword
    let found: Set<Cell>
    let hinted: Set<Cell>

    var body: some View {
        GeometryReader { proxy in
            let cols = max(crossword.cols, 1)
            let rows = max(crossword.rows, 1)
            let cell = min(proxy.size.width / CGFloat(cols), proxy.size.height / CGFloat(rows), 40)
            let letters = crossword.letters.sorted { ($0.key.row, $0.key.col) < ($1.key.row, $1.key.col) }
            ZStack(alignment: .topLeading) {
                ForEach(letters, id: \.key) { position, letter in
                    cellView(position, letter, size: cell)
                        .offset(x: cell * CGFloat(position.col), y: cell * CGFloat(position.row))
                }
            }
            .frame(width: cell * CGFloat(cols), height: cell * CGFloat(rows), alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cellView(_ position: Cell, _ letter: Character, size: CGFloat) -> some View {
        let isFound = found.contains(position)
        let shown = isFound || hinted.contains(position)
        let fill = isFound ? WheelColors.cellFound : hinted.contains(position) ? WheelColors.cellHinted : WheelColors.cell
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(fill)
            if shown {
                Text(String(letter))
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(isFound ? WheelColors.cellText : WheelColors.letterText)
            }
        }
        .padding(2)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shown ? String(letter) : "")
        .accessibilityIdentifier("cell_r\(position.row + 1)c\(position.col + 1)")
    }
}

struct WordWheelLetterWheel: View {
    let letters: [Character]
    let chosen: [Int]
    let onChosenChange: ([Int]) -> Void
    let onSwipeEnd: () -> Void

    @State private var finger: CGPoint?
    @State private var swiping = false

    private static let tapSlop: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            let letterSize = size * 0.24
            let radius = (size - letterSize) / 2 - 8
            let centres = letters.indices.map { index in
                let angle = 2 * Double.pi * Double(index) / Double(letters.count) - Double.pi / 2
                return CGPoint(x: size / 2 + radius * cos(angle), y: size / 2 + radius * sin(angle))
            }
            ZStack(alignment: .topLeading) {
                Circle().fill(WheelColors.wheel)
                lines(centres)
                ForEach(letters.indices, id: \.self) { index in
                    letterView(index, size: letterSize)
                        .position(centres[index])
                }
            }
            .contentShape(Circle())
            .onDisappear {
                swiping = false
                finger = nil
            }
            .gesture(drag(centres: centres, hit: letterSize / 2))
        }
    }

    private func lines(_ centres: [CGPoint]) -> some View {
        Path { path in
            guard let first = chosen.first else {
                return
            }
            path.move(to: centres[first])
            for index in chosen.dropFirst() {
                path.addLine(to: centres[index])
            }
            if let finger {
                path.addLine(to: finger)
            }
        }
        .stroke(WheelColors.line, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        .allowsHitTesting(false)
    }

    private func letterView(_ index: Int, size: CGFloat) -> some View {
        let selected = chosen.contains(index)
        return Text(String(letters[index]))
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(selected ? WheelColors.chosenText : WheelColors.letterText)
            .frame(width: size, height: size)
            .background(selected ? WheelColors.chosen : WheelColors.letter, in: Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(letters[index]))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("wheel_letter_\(index + 1)")
            .accessibilityAction {
                if !chosen.contains(index) {
                    onChosenChange(chosen + [index])
                }
            }
    }

    private func drag(centres: [CGPoint], hit: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !swiping, hypot(value.translation.width, value.translation.height) >= Self.tapSlop {
                    swiping = true
                    let start = letter(at: value.startLocation, centres: centres, hit: hit)
                    onChosenChange(start.map { [$0] } ?? [])
                }
                guard swiping else {
                    return
                }
                finger = value.location
                onChosenChange(
                    WordWheelSwipe.path(chosen, entering: letter(at: value.location, centres: centres, hit: hit))
                )
            }
            .onEnded { value in
                if swiping {
                    swiping = false
                    finger = nil
                    onSwipeEnd()
                } else if let index = letter(at: value.location, centres: centres, hit: hit),
                    !chosen.contains(index)
                {
                    onChosenChange(chosen + [index])
                }
            }
    }

    private func letter(at point: CGPoint, centres: [CGPoint], hit: CGFloat) -> Int? {
        centres.firstIndex { hypot($0.x - point.x, $0.y - point.y) < hit }
    }
}

enum WordWheelSwipe {
    static func path(_ path: [Int], entering index: Int?) -> [Int] {
        guard let index, path.last != index else {
            return path
        }
        if path.count > 1, path[path.count - 2] == index {
            return Array(path.dropLast())
        }
        return path.contains(index) ? path : path + [index]
    }
}

extension View {
    fileprivate func tourTarget(_ key: String, in bounds: Binding<[String: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: {
            bounds.wrappedValue[key] = $0
        }
    }
}
