import SudokuEngine
import SwiftUI
import UIKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case sudoku = "Sudoku"
    case solitaire = "Solitaire"
    case twoTone = "Two Tone"
    case sightlines = "Sightlines"
    case fiveLetters = "Five Letters"
    case kakuro = "Kakuro"
    case slideOut = "Slide Out"
    case wordWheel = "Word Wheel"

    var id: Self {
        self
    }

    var tag: String {
        switch self {
        case .general:
            "general"
        case .sudoku:
            "sudoku"
        case .solitaire:
            "solitaire"
        case .twoTone:
            "two_tone"
        case .sightlines:
            "sightlines"
        case .fiveLetters:
            "five_letters"
        case .kakuro:
            "kakuro"
        case .slideOut:
            "slide_out"
        case .wordWheel:
            "word_wheel"
        }
    }

    var accent: Color {
        let pair: (UInt32, UInt32) =
            switch self {
            case .general, .sudoku:
                (0x1565D8, 0x7DB5FF)
            case .solitaire:
                (0x2E8B57, 0x5CC58A)
            case .twoTone:
                (0xE0603F, 0xEC7F62)
            case .sightlines:
                (0x2A93B3, 0x52BDDC)
            case .fiveLetters:
                (0x4F9A53, 0x72BF6D)
            case .kakuro:
                (0x7C5CD6, 0xA993F2)
            case .slideOut:
                (0xC27A2C, 0xE3A85C)
            case .wordWheel:
                (0x4F5BD5, 0x939BFF)
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
}

struct SettingsHubView: View {
    var sudokuMode = GameMode.classic
    var onBack: (() -> Void)?

    @State private var tab: SettingsTab
    @Environment(\.dismiss) private var dismiss

    init(initial: SettingsTab = .general, sudokuMode: GameMode = .classic, onBack: (() -> Void)? = nil) {
        _tab = State(initialValue: initial)
        self.sudokuMode = sudokuMode
        self.onBack = onBack
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    PuzzleIcon.image("chevron.left").font(.title3).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("back")
                Text("Settings").font(.title)
            }
            .padding(.horizontal, 8)
            tabs
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(LinearGradient(colors: [tab.accent.opacity(0.1), .clear], startPoint: .top, endPoint: .center))
                .tint(tab.accent)
                .id(tab)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var tabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(SettingsTab.allCases) { option in
                        Button {
                            tab = option
                        } label: {
                            VStack(spacing: 6) {
                                Text(option.rawValue)
                                    .foregroundStyle(tab == option ? option.accent : .secondary)
                                Capsule().fill(tab == option ? option.accent : .clear).frame(height: 3)
                            }
                            .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .id(option)
                        .accessibilityIdentifier("settings_tab_\(option.tag)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(tab, anchor: .center) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .general:
            ScrollView {
                VStack(spacing: 0) {
                    SudokuGeneralSettings()
                    AccountSettings()
                }
            }
        case .sudoku:
            SudokuSettingsView(initialMode: sudokuMode)
        case .solitaire:
            SolitaireSettingsView {}
        case .twoTone:
            TwoToneSettingsView()
        case .sightlines:
            SightlinesSettingsView()
        case .fiveLetters:
            FiveLettersSettingsView()
        case .kakuro:
            KakuroSettingsView(onBack: {})
        case .slideOut:
            SlideOutSettingsScreen {}
        case .wordWheel:
            WordWheelSettingsView()
        }
    }
}
