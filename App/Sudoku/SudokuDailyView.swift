import PuzzlesCore
import SudokuEngine
import SwiftUI

struct SudokuDailyView: View {
    @Environment(SudokuNavigator.self) private var navigator
    @Environment(\.sudokuPalette) private var palette
    @State private var month = Calendar.current.dateComponents([.year, .month], from: Date())
    @State private var chosen: CalendarDay?

    private let store = SudokuStore.shared
    private let today = sudokuToday()

    var body: some View {
        let days = store.dailyResults
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        SudokuBackButton(action: navigator.back)
                        Text("Daily puzzles").font(.title.weight(.regular))
                        Spacer()
                    }
                    monthHeader
                    weekHeader
                    grid(days)
                    legend
                }
                .padding(16)
            }
            if let chosen {
                choice(chosen, days[chosen])
            }
        }
    }

    private var firstOfMonth: Date {
        Calendar.current.date(from: month) ?? Date()
    }

    private var canGoForward: Bool {
        firstOfMonth < Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var monthHeader: some View {
        HStack {
            SudokuIconButton(symbol: "chevron.backward", label: "Previous month", id: "month_previous") { shift(-1) }
            Text(firstOfMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("month_title")
            SudokuIconButton(
                symbol: "chevron.forward", label: "Next month", id: "month_next", enabled: canGoForward
            ) { shift(1) }
        }
    }

    private func shift(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: firstOfMonth) else {
            return
        }
        month = Calendar.current.dateComponents([.year, .month], from: next)
    }

    private var weekHeader: some View {
        HStack {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                Text(day).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ days: [CalendarDay: DailyDay]) -> some View {
        let first = sudokuDay(firstOfMonth)
        let count = Calendar.current.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let leading = (first.daysSinceEpoch + 3) % 7
        let cells: [CalendarDay?] =
            [CalendarDay?](repeating: nil, count: leading) + (0..<count).map { first.adding(days: $0) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date, days[date])
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(_ date: CalendarDay, _ day: DailyDay?) -> some View {
        let future = date > today
        let medal = day?.medal ?? .none
        let description: String
        if medal == .gold {
            description = "gold medal"
        } else if medal == .silver {
            description = "silver medal"
        } else if day?.doneLate == true {
            description = "done later"
        } else {
            description = "not done"
        }
        return Button {
            chosen = date
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if medal != .none {
                        SudokuMedal(medal: medal, size: 30)
                    }
                    Text("\(dayNumber(date))")
                        .foregroundStyle(future ? Color.secondary : palette.enteredDigit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if day?.doneLate == true {
                    Text("✓").foregroundStyle(palette.accent)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if date == today {
                    Circle().stroke(palette.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel("\(date.longLabel), \(description)")
        .accessibilityIdentifier(date == today ? "daily_today" : "daily_day_\(date.isoString)")
    }

    private func dayNumber(_ date: CalendarDay) -> Int {
        Int(date.isoString.suffix(2)) ?? 0
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(AnyView(SudokuMedal(medal: .gold)), "Gold: both dailies on the day")
            legendRow(AnyView(SudokuMedal(medal: .silver)), "Silver: one daily on the day")
            legendRow(AnyView(Text("✓").foregroundStyle(palette.accent)), "Done on a later day")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ marker: AnyView, _ text: String) -> some View {
        HStack {
            marker.frame(width: 28)
            Text(text).font(.footnote)
        }
    }

    private func choice(_ date: CalendarDay, _ day: DailyDay?) -> some View {
        SudokuDialog(id: "daily_choice", title: date.longLabel, onDismiss: { chosen = nil }) {
            ForEach(GameMode.allCases, id: \.self) { mode in
                let done = (day?.status(mode) ?? .notDone) != .notDone
                let level = levelLabel(BankPick.dailyLevel(mode: mode, date: date))
                Button {
                    chosen = nil
                    Task {
                        if let id = await store.openDaily(mode: mode, date: date) {
                            navigator.openGame(id)
                        }
                    }
                } label: {
                    Text("\(mode.label) · \(level)\(done ? "  ✓" : "")")
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .overlay(Capsule().stroke(palette.thinLine))
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("daily_play_\(mode.slug)")
            }
            HStack {
                Spacer()
                SudokuTextButton(title: "Close", id: "daily_close") { chosen = nil }
            }
        }
    }
}
