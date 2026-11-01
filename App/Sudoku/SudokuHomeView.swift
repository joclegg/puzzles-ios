import PuzzlesCore
import SudokuEngine
import SwiftUI

struct SudokuHomeView: View {
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette
    @State private var mode = GameMode.classic
    @State private var resumeChoice: (level: Difficulty, game: SudokuSavedGame)?
    @State private var starting = false

    private let store = SudokuStore.shared

    var body: some View {
        let inProgress = store.inProgress
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    hero
                    if let latest = inProgress.first {
                        continueCard(latest)
                    }
                    SudokuSegments(
                        options: GameMode.allCases, selected: mode, label: \.label, id: { "mode_\($0.slug)" },
                        onSelect: { mode = $0 })
                    section("Today", aside: sudokuToday().shortLabel) {
                        today
                    }
                    section("New game", aside: nil) {
                        levels(inProgress)
                    }
                }
                .padding(16)
            }
            if let choice = resumeChoice {
                resumeDialog(choice.level, choice.game)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            SudokuBackButton(action: navigator.back)
            Text("Sudoku").font(.largeTitle.weight(.regular))
            Spacer()
            DailyCalendarButton(tab: .sudoku)
            SudokuIconButton(symbol: "chart.bar", label: "Best times", id: "stats") { navigator.push(.stats) }
            SudokuIconButton(symbol: "clock.arrow.circlepath", label: "History", id: "history") {
                navigator.push(.history)
            }
            SudokuIconButton(symbol: "gearshape", label: "Settings", id: "settings") {
                navigator.push(.settings(mode))
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            SudokuGameIcon()
                .frame(width: 80, height: 80)
                .background(palette.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 1)
            Text("Classic and killer, from 6x6 to evil")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [palette.accent.opacity(0.2), palette.accent.opacity(0.06), .clear], startPoint: .topLeading,
                endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.accent.opacity(0.25)))
    }

    private func continueCard(_ game: SudokuSavedGame) -> some View {
        Button {
            navigator.openGame(game.id)
        } label: {
            HStack(spacing: 16) {
                PuzzleIcon.image("play.fill")
                    .foregroundStyle(palette.background)
                    .frame(width: 48, height: 48)
                    .background(palette.accent, in: Circle())
                VStack(alignment: .leading) {
                    Text("Continue").font(.headline)
                    Text("\(game.title) · \(formatDuration(game.elapsedMs))")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.forward").foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .modifier(SudokuTileStyle(active: true, radius: 24))
        }
        .buttonStyle(SudokuPressStyle())
        .accessibilityIdentifier("continue")
    }

    private func section<Content: View>(_ title: String, aside: String?, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(spacing: 8) {
            HStack {
                Text(title.uppercased()).font(.caption.weight(.semibold)).kerning(1.2)
                Spacer()
                if let aside {
                    Text(aside).font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            content()
        }
    }

    private var today: some View {
        let date = sudokuToday()
        let solved = Set(store.completedDailies.map(\.id))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(mode.levels, id: \.self) { level in
                dailyTile(level, done: solved.contains(DailyIds.of(mode: mode, difficulty: level, date: date)), date: date)
            }
        }
    }

    private func dailyTile(_ level: Difficulty, done: Bool, date: CalendarDay) -> some View {
        Button {
            launch { try? await store.openDaily(mode: mode, difficulty: level, date: date) }
        } label: {
            VStack(spacing: 4) {
                Text(levelLabel(level)).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                if done {
                    PuzzleIcon.image("checkmark.circle.fill").foregroundStyle(palette.accent)
                } else {
                    Text("Play").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
            .modifier(SudokuTileStyle(active: done))
        }
        .buttonStyle(SudokuPressStyle())
        .accessibilityIdentifier("daily_\(level.name.lowercased())")
    }

    private func levels(_ inProgress: [SudokuSavedGame]) -> some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(mode.levels.enumerated()), id: \.element) { index, level in
                    levelTile(level, rank: index, saved: saved(inProgress, level))
                }
            }
            Button {
                navigator.push(.entry(mode))
            } label: {
                tileLabel("Enter puzzle", symbol: "pencil", trailing: true)
                    .modifier(SudokuTileStyle())
            }
            .buttonStyle(SudokuPressStyle())
            .accessibilityIdentifier("enter_puzzle")
        }
    }

    private func saved(_ inProgress: [SudokuSavedGame], _ level: Difficulty) -> SudokuSavedGame? {
        inProgress.first { $0.ref.slot == PuzzleRef.levelSlot(mode: mode, difficulty: level) }
    }

    private func levelTile(_ level: Difficulty, rank: Int, saved: SudokuSavedGame?) -> some View {
        Button {
            if let saved {
                resumeChoice = (level, saved)
            } else {
                launch { await store.startNew(mode: mode, difficulty: level) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(levelLabel(level)).font(.headline)
                    HStack(spacing: 4) {
                        ForEach(0..<mode.levels.count, id: \.self) { index in
                            Capsule()
                                .fill(index <= rank ? palette.accent : Color.primary.opacity(0.14))
                                .frame(width: 12, height: 6)
                        }
                    }
                    if let saved {
                        HStack(spacing: 6) {
                            Circle().fill(palette.accent).frame(width: 6, height: 6)
                            Text("In progress · \(formatDuration(saved.elapsedMs))")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                PuzzleIcon.image("chevron.forward").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxHeight: .infinity)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            .modifier(SudokuTileStyle(active: saved != nil))
        }
        .buttonStyle(SudokuPressStyle())
        .accessibilityIdentifier("level_\(level.name.lowercased())")
    }

    private func tileLabel(_ title: String, symbol: String, trailing: Bool) -> some View {
        HStack(spacing: 12) {
            PuzzleIcon.image(symbol)
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.headline)
            Spacer(minLength: 0)
            if trailing {
                PuzzleIcon.image("chevron.forward").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func resumeDialog(_ level: Difficulty, _ game: SudokuSavedGame) -> some View {
        SudokuDialog(id: "resume_dialog", title: "\(mode.label) · \(levelLabel(level))", onDismiss: { resumeChoice = nil }) {
            Text("You have a game in progress (\(formatDuration(game.elapsedMs))).")
            HStack {
                Spacer()
                SudokuTextButton(title: "New game", id: "new_game") {
                    resumeChoice = nil
                    launch { await store.startNew(mode: mode, difficulty: level) }
                }
                SudokuTextButton(title: "Resume", id: "resume_game") {
                    resumeChoice = nil
                    navigator.openGame(game.id)
                }
            }
        }
    }

    private func launch(_ start: @escaping () async -> Int?) {
        if starting {
            return
        }
        starting = true
        Task {
            if let id = await start() {
                navigator.openGame(id)
            }
            starting = false
        }
    }
}

struct SudokuGameIcon: View {
    @Environment(\.sudokuPalette) private var palette

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let cell = side / 3
            context.fill(
                Path(CGRect(x: 0, y: 0, width: cell, height: cell)), with: .color(palette.givenCell))
            context.fill(
                Path(CGRect(x: cell * 2, y: cell * 2, width: cell, height: cell)), with: .color(palette.givenCell))
            context.fill(
                Path(CGRect(x: cell, y: cell, width: cell, height: cell)), with: .color(palette.selected))
            var lines = Path()
            for line in 0...3 {
                let at = CGFloat(line) * cell
                lines.move(to: CGPoint(x: at, y: 0))
                lines.addLine(to: CGPoint(x: at, y: side))
                lines.move(to: CGPoint(x: 0, y: at))
                lines.addLine(to: CGPoint(x: side, y: at))
            }
            context.stroke(lines, with: .color(palette.thickLine), lineWidth: 2)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

extension CalendarDay {
    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: sudokuDate(self))
    }

    var longLabel: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: sudokuDate(self))
    }
}
