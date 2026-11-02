import SwiftUI

struct HomeSection<Content: View>: View {
    enum Style {
        case caps
        case headline(spacing: CGFloat)
    }

    let title: String
    let aside: String?
    let style: Style
    let content: Content

    init(_ title: String, aside: String?, style: Style, @ViewBuilder content: () -> Content) {
        self.title = title
        self.aside = aside
        self.style = style
        self.content = content()
    }

    var body: some View {
        switch style {
        case .caps:
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
                content
            }
        case .headline(let spacing):
            VStack(alignment: .leading, spacing: spacing) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if let aside {
                        Text(aside).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                content
            }
        }
    }
}
