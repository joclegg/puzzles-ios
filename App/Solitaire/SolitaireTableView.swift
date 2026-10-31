import SolitaireEngine
import SwiftUI

private struct TableMetrics {
    static let gap: CGFloat = 4
    static let faceDownStep: CGFloat = 0.14
    static let faceUpStep: CGFloat = 0.3
    static let wasteFan: CGFloat = 0.32

    let size: CGSize

    var cardWidth: CGFloat {
        (size.width - TableMetrics.gap * CGFloat(Board.columnCount - 1)) / CGFloat(Board.columnCount)
    }

    var cardHeight: CGFloat {
        cardWidth * 1.45
    }

    var tableauTop: CGFloat {
        cardHeight + TableMetrics.gap * 3
    }

    var tableauHeight: CGFloat {
        max(size.height - tableauTop, cardHeight)
    }

    func columnX(_ index: Int) -> CGFloat {
        (cardWidth + TableMetrics.gap) * CGFloat(index)
    }

    func foundationX(_ index: Int) -> CGFloat {
        columnX(Board.columnCount - Board.foundationCount + index)
    }

    func dropTarget(at point: CGPoint, excluding pile: Pile) -> Pile? {
        for index in 0..<Board.foundationCount where pile != .foundation(index) {
            let rect = CGRect(x: foundationX(index), y: 0, width: cardWidth, height: cardHeight)
            if rect.contains(point) {
                return .foundation(index)
            }
        }
        for index in 0..<Board.columnCount where pile != .tableau(index) {
            let rect = CGRect(x: columnX(index), y: tableauTop, width: cardWidth, height: tableauHeight)
            if rect.contains(point) {
                return .tableau(index)
            }
        }
        return nil
    }

    func offsets(_ column: Column) -> [CGFloat] {
        let faceDown = min(column.faceUpFrom, column.cards.count)
        let faceUp = column.cards.count - faceDown
        let wanted =
            cardHeight * TableMetrics.faceDownStep * CGFloat(faceDown)
            + cardHeight * TableMetrics.faceUpStep * CGFloat(max(faceUp - 1, 0))
        let squeeze = wanted + cardHeight > tableauHeight && wanted > 0 ? min(max((tableauHeight - cardHeight) / wanted, 0), 1) : 1
        var top: CGFloat = 0
        var result: [CGFloat] = []
        for index in column.cards.indices {
            result.append(top)
            let step = column.isFaceUp(index) ? TableMetrics.faceUpStep : TableMetrics.faceDownStep
            top += cardHeight * squeeze * step
        }
        return result
    }
}

private struct PlacedCard: Identifiable {
    let id: String
    let card: Card
    let faceUp: Bool
    let pile: Pile
    let index: Int
    let position: CGPoint
    let layer: Double
    let interactive: Bool

    var identity: String {
        "\(pile)-\(id)"
    }
}

private struct CardDrag: Equatable {
    let pile: Pile
    let index: Int
    var offset: CGSize

    func lifts(_ pile: Pile, _ index: Int) -> Bool {
        self.pile == pile && index >= self.index
    }
}

struct SolitaireTableView: View {
    let model: SolitaireGameModel
    let state: GameState
    @State private var drag: CardDrag?

    var body: some View {
        GeometryReader { proxy in
            let metrics = TableMetrics(size: proxy.size)
            ZStack(alignment: .topLeading) {
                piles(metrics)
                ForEach(placed(metrics), id: \.identity) { placed in
                    cardView(placed, metrics)
                }
            }
            .coordinateSpace(name: "table")
        }
        .padding(TableMetrics.gap)
        .background(SolitaireColors.felt)
        .accessibilityElement(children: .contain)
    }

    private func placed(_ metrics: TableMetrics) -> [PlacedCard] {
        var result: [PlacedCard] = []
        let board = state.board
        let shown = board.waste.suffix(state.drawMode.cards)
        for (position, card) in shown.enumerated() {
            let index = board.waste.count - shown.count + position
            result.append(
                PlacedCard(
                    id: "card_\(card.code)",
                    card: card,
                    faceUp: true,
                    pile: .waste,
                    index: index,
                    position: CGPoint(x: metrics.columnX(1) + metrics.cardWidth * TableMetrics.wasteFan * CGFloat(position), y: 0),
                    layer: Double(position),
                    interactive: index == board.waste.count - 1
                )
            )
        }
        for (pileIndex, cards) in board.foundations.enumerated() {
            if let top = cards.last {
                result.append(
                    PlacedCard(
                        id: "card_\(top.code)",
                        card: top,
                        faceUp: true,
                        pile: .foundation(pileIndex),
                        index: cards.count - 1,
                        position: CGPoint(x: metrics.foundationX(pileIndex), y: 0),
                        layer: 1,
                        interactive: true
                    )
                )
            }
        }
        for (columnIndex, column) in board.tableau.enumerated() {
            let offsets = metrics.offsets(column)
            for (index, card) in column.cards.enumerated() {
                let faceUp = column.isFaceUp(index)
                result.append(
                    PlacedCard(
                        id: faceUp ? "card_\(card.code)" : "tableau_\(columnIndex + 1)_down_\(index + 1)",
                        card: card,
                        faceUp: faceUp,
                        pile: .tableau(columnIndex),
                        index: index,
                        position: CGPoint(x: metrics.columnX(columnIndex), y: metrics.tableauTop + offsets[index]),
                        layer: 10 + Double(index),
                        interactive: faceUp
                    )
                )
            }
        }
        return result
    }

    @ViewBuilder
    private func piles(_ metrics: TableMetrics) -> some View {
        stock(metrics)
        Color.clear
            .frame(width: metrics.cardWidth * 2 + TableMetrics.gap, height: metrics.cardHeight)
            .accessibilityElement()
            .accessibilityIdentifier("waste")
            .allowsHitTesting(false)
            .offset(x: metrics.columnX(1))
        ForEach(0..<Board.foundationCount, id: \.self) { index in
            let starter = Card(rank: state.order.foundationStarter, suit: Suit.allCases[index]).rankLabel
            emptyPile(.foundation(index), tag: "foundation_\(index + 1)", starter: starter, metrics)
                .offset(x: metrics.foundationX(index))
        }
        ForEach(0..<Board.columnCount, id: \.self) { index in
            emptyPile(.tableau(index), tag: "tableau_\(index + 1)", starter: nil, metrics)
                .offset(x: metrics.columnX(index), y: metrics.tableauTop)
        }
    }

    private func stock(_ metrics: TableMetrics) -> some View {
        let count = state.board.stock.count
        return ZStack(alignment: .bottomTrailing) {
            Button(action: model.onStockClick) {
                ZStack {
                    if count > 0 {
                        SolitaireCardBack()
                    } else {
                        RoundedRectangle(cornerRadius: 5).fill(SolitaireColors.emptyPile)
                        Text("↻").font(.system(size: 22)).foregroundStyle(SolitaireColors.onFelt)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stock")
            .accessibilityIdentifier("stock")
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(SolitaireColors.onFelt)
                    .padding(4)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("stock_count")
            }
        }
        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
    }

    private func emptyPile(_ pile: Pile, tag: String, starter: String?, _ metrics: TableMetrics) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(SolitaireColors.emptyPile)
            if let starter {
                Text(starter)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SolitaireColors.onFelt)
            }
        }
        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.onEmptyPileClick(pile) }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(tag)
    }

    private func isSelected(_ pile: Pile, _ index: Int) -> Bool {
        guard let selection = state.selection, selection.pile == pile else {
            return false
        }
        return index >= state.board.cardsIn(pile).count - selection.count
    }

    @ViewBuilder
    private func cardView(_ placed: PlacedCard, _ metrics: TableMetrics) -> some View {
        let lifted = drag?.lifts(placed.pile, placed.index) ?? false
        let base = Group {
            if placed.faceUp {
                SolitaireCardFace(card: placed.card, width: metrics.cardWidth, selected: isSelected(placed.pile, placed.index))
            } else {
                SolitaireCardBack()
                    .accessibilityElement()
            }
        }
        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
        .modifier(SolitaireLanding(celebrate: model.finishing && isFoundation(placed.pile)))
        .accessibilityIdentifier(placed.id)
        .offset(x: placed.position.x, y: placed.position.y)
        .offset(lifted ? (drag?.offset ?? .zero) : .zero)
        .zIndex(lifted ? 1000 + placed.layer : placed.layer)
        if placed.interactive {
            base
                .contentShape(Rectangle())
                .onTapGesture { model.onCardClick(placed.pile, placed.index) }
                .gesture(dragGesture(placed, metrics))
        } else {
            base.allowsHitTesting(false)
        }
    }

    private func isFoundation(_ pile: Pile) -> Bool {
        if case .foundation = pile {
            return true
        }
        return false
    }

    private func dragGesture(_ placed: PlacedCard, _ metrics: TableMetrics) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("table"))
            .onChanged { value in
                drag = CardDrag(pile: placed.pile, index: placed.index, offset: value.translation)
            }
            .onEnded { value in
                drag = nil
                if let target = metrics.dropTarget(at: value.location, excluding: placed.pile) {
                    model.onCardDrop(placed.pile, placed.index, target)
                }
            }
    }
}

private struct SolitaireLanding: ViewModifier {
    let celebrate: Bool
    @State private var popped = false

    func body(content: Content) -> some View {
        let lift: CGFloat = celebrate && !popped ? 1 : 0
        content
            .scaleEffect(1 + lift * 0.5)
            .rotationEffect(.degrees(lift * -18))
            .offset(y: -lift * 40)
            .onAppear {
                withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                    popped = true
                }
            }
    }
}

struct SolitaireCardFace: View {
    let card: Card
    let width: CGFloat
    let selected: Bool

    var body: some View {
        let ink = card.suit.isRed ? SolitaireColors.redSuit : SolitaireColors.blackSuit
        let shape = RoundedRectangle(cornerRadius: 5)
        ZStack(alignment: .topLeading) {
            shape.fill(selected ? SolitaireColors.selected : SolitaireColors.cardFace)
            Text(card.rankLabel)
                .font(.system(size: width * 0.36, weight: .bold))
                .foregroundStyle(ink)
                .padding(.leading, 4)
                .padding(.top, 1)
            Text(String(card.suit.symbol))
                .font(.system(size: width * 0.55))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, width * 0.3)
            shape.stroke(SolitaireColors.cardEdge, lineWidth: 1)
        }
        .clipShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.rankLabel)\(String(card.suit.symbol))")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

struct SolitaireCardBack: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        ZStack {
            shape.fill(SolitaireColors.cardBack)
            RoundedRectangle(cornerRadius: 3)
                .stroke(SolitaireColors.cardBackPattern, lineWidth: 1)
                .padding(4)
            shape.stroke(SolitaireColors.cardEdge, lineWidth: 1)
        }
    }
}
