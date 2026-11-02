import PuzzlesCore
import SwiftUI
import UIKit

func medalColour(_ medal: Medal) -> Color {
    let pair: (UInt32, UInt32)?
    switch medal {
    case .none:
        pair = nil
    case .bronze:
        pair = (0xA9713F, 0xC58A55)
    case .silver:
        pair = (0x8E97A3, 0xAEB6C1)
    case .gold:
        pair = (0xD9A93A, 0xE2B33C)
    }
    guard let pair else {
        return .primary
    }
    return Color(
        uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? pair.1 : pair.0
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }
    )
}

struct DailyCalendarButton: View {
    let tab: SettingsTab

    var body: some View {
        let medal = tab.dailyDayMap[.today]?.medal ?? Medal.none
        ZStack {
            Button {
                DailyRouter.shared.openCalendar(tab)
            } label: {
                PuzzleIcon.image("calendar")
                    .foregroundStyle(medalColour(medal))
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Daily calendar")
            .accessibilityIdentifier("daily_calendar")
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(medal == .none ? "No medal" : "\(medal.rawValue) medal")
                .accessibilityIdentifier("calendar_medal_\(medal.rawValue)")
        }
    }
}

struct DailyCalendarView: View {
    let tab: SettingsTab

    @State private var firstOfMonth = CalendarDay.today.firstOfMonth
    @State private var chosen: CalendarDay?

    private let today = CalendarDay.today

    var body: some View {
        let days = tab.dailyDayMap
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Button {
                            DailyRouter.shared.back()
                        } label: {
                            PuzzleIcon.image("chevron.left").font(.title3).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back")
                        .accessibilityIdentifier("back")
                        Text("Daily calendar").font(.title)
                        Spacer()
                    }
                    monthHeader
                    weekHeader
                    grid(days)
                }
                .padding(16)
            }
            if let chosen {
                choices(chosen)
            }
        }
        .tint(tab.accent)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var monthHeader: some View {
        HStack {
            Button("‹") { firstOfMonth = firstOfMonth.addingMonths(-1) }
                .accessibilityIdentifier("month_previous")
            Text(sudokuDate(firstOfMonth).formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("month_title")
            Button("›") { firstOfMonth = firstOfMonth.addingMonths(1) }
                .disabled(firstOfMonth >= today.firstOfMonth)
                .accessibilityIdentifier("month_next")
        }
        .font(.title2)
    }

    private var weekHeader: some View {
        HStack {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                Text(day).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ days: [CalendarDay: DailyDay]) -> some View {
        let count = firstOfMonth.addingMonths(1).days(since: firstOfMonth)
        let leading = (firstOfMonth.daysSinceEpoch + 3) % 7
        let cells: [CalendarDay?] =
            [CalendarDay?](repeating: nil, count: leading) + (0..<count).map { firstOfMonth.adding(days: $0) }
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
        let medal = day?.medal ?? Medal.none
        let description: String
        if medal != .none {
            description = "\(medal.rawValue) medal"
        } else if day?.doneLate == true {
            description = "done later"
        } else {
            description = "not done"
        }
        return ZStack(alignment: .bottomTrailing) {
            Button {
                chosen = date
            } label: {
                Text("\(date.dayOfMonth)")
                    .foregroundStyle(future ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if medal != .none {
                            MedalBadge(medal: medal)
                        }
                    }
                    .overlay {
                        if date == today {
                            Circle().stroke(tab.accent, lineWidth: 2)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(future)
            .accessibilityLabel("\(date.longLabel), \(description)")
            if medal != .none {
                Color.clear
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("\(medal.rawValue) medal")
                    .accessibilityIdentifier("medal_\(medal.rawValue)")
            }
            if day?.doneLate == true {
                Text("✓").foregroundStyle(tab.accent).allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(date == today ? "daily_today" : "daily_day_\(date.isoString)")
    }

    private func choices(_ date: CalendarDay) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture { chosen = nil }
            VStack(alignment: .leading, spacing: 12) {
                Text(date.longLabel).font(.title3.weight(.semibold))
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(tab.dailies(on: date), id: \.tag) { daily in
                            Button {
                                chosen = nil
                                DailyRouter.shared.open(daily)
                            } label: {
                                Text(daily.done ? "\(daily.calendarLabel) ✓" : daily.calendarLabel)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .padding(.horizontal, 8)
                                    .overlay(Capsule().stroke(tab.accent.opacity(0.5)))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(daily.tag)
                        }
                    }
                }
                .frame(maxHeight: 320)
                .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Close") { chosen = nil }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("daily_choice")
        }
    }
}

private struct MedalBadge: View {
    let medal: Medal
    var size: CGFloat = 30

    var body: some View {
        Circle()
            .fill(medalColour(medal))
            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: size / 8))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension CalendarDay {
    fileprivate var parts: [Int] {
        isoString.split(separator: "-").compactMap { Int($0) }
    }

    var dayOfMonth: Int {
        parts[2]
    }

    var firstOfMonth: CalendarDay {
        adding(days: 1 - dayOfMonth)
    }

    func addingMonths(_ months: Int) -> CalendarDay {
        let index = parts[0] * 12 + parts[1] - 1 + months
        return CalendarDay(year: index / 12, month: index % 12 + 1, day: 1)
    }
}
