import SwiftUI

struct GameHomeScaffold<
    Header: View, Hero: View, Continue: View, Intro: View, Today: View, NewPuzzle: View, Footer: View, Chrome: ViewModifier,
    Dialog: View
>: View {
    let alignment: HorizontalAlignment
    let chrome: Chrome
    let header: Header
    let hero: Hero
    let continueCard: Continue
    let intro: Intro
    let today: Today
    let newPuzzle: NewPuzzle
    let footer: Footer
    let dialog: Dialog

    init(
        alignment: HorizontalAlignment = .center,
        chrome: Chrome,
        @ViewBuilder header: () -> Header,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder continueCard: () -> Continue,
        @ViewBuilder intro: () -> Intro,
        @ViewBuilder today: () -> Today,
        @ViewBuilder newPuzzle: () -> NewPuzzle,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder dialog: () -> Dialog
    ) {
        self.alignment = alignment
        self.chrome = chrome
        self.header = header()
        self.hero = hero()
        self.continueCard = continueCard()
        self.intro = intro()
        self.today = today()
        self.newPuzzle = newPuzzle()
        self.footer = footer()
        self.dialog = dialog()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: alignment, spacing: 20) {
                header
                hero
                continueCard
                intro
                today
                newPuzzle
                footer
            }
            .padding(16)
        }
        .modifier(chrome)
        .overlay {
            dialog
        }
    }
}

struct GameHero<Icon: View>: View {
    let accent: Color
    let tagline: String
    let taglineFont: Font?
    let taglineStyle: AnyShapeStyle
    let taglineFillsWidth: Bool
    let bordered: Bool
    let icon: Icon

    init(
        accent: Color,
        tagline: String,
        taglineFont: Font? = nil,
        taglineStyle: AnyShapeStyle = AnyShapeStyle(.secondary),
        taglineFillsWidth: Bool = false,
        bordered: Bool = true,
        @ViewBuilder icon: () -> Icon
    ) {
        self.accent = accent
        self.tagline = tagline
        self.taglineFont = taglineFont
        self.taglineStyle = taglineStyle
        self.taglineFillsWidth = taglineFillsWidth
        self.bordered = bordered
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 16) {
            icon
            if taglineFillsWidth {
                taglineText.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                taglineText
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.2), accent.opacity(0.06), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.25), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var taglineText: some View {
        if let taglineFont {
            Text(tagline).font(taglineFont).foregroundStyle(taglineStyle)
        } else {
            Text(tagline).foregroundStyle(taglineStyle)
        }
    }
}

extension View {
    func gameHeroBadge(background: Color) -> some View {
        frame(width: 80, height: 80)
            .background(background, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 1)
    }
}
