//
//  TripRecapShareCarousel.swift
//  Lezgo
//

import SwiftUI

/// The pictures of the trip recap side by side. The one in the middle is big, the ones on both sides peek out and
/// are a little smaller. Swiping moves one picture at a time and loops: past the last picture comes the first.
///
/// It shows no names or counters. VoiceOver reads the format name and swipes up and down to change it.
struct TripRecapShareCarousel: View {
    let options: [TripRecapShareOption]
    @Binding var selectedIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Which card is in the middle, as a continuous index (see `LoopingPosition`). It follows the finger while
    /// dragging and is animated to a whole number on release.
    @State private var position = 0.0
    @State private var dragStartPosition: Double?
    @State private var size = CGSize.zero

    /// The middle card takes this much of the width, so the side cards have room to peek out.
    private let widthShare = 0.8
    private let sideShrink = 0.12
    private let gap = 14.0
    private let nudgePosition = 0.2

    /// With fewer than three pictures there is no picture left for both sides, and the one picture that is the
    /// neighbour on both sides would jump from one side to the other while swiping. The pictures are listed twice
    /// then, so that each side has its own card.
    private var slots: [TripRecapShareOption] { options.count < 3 ? options + options : options }
    private var looping: LoopingPosition { LoopingPosition(count: slots.count) }
    private var cardWidth: CGFloat { min(size.width * widthShare, max(size.height - 16, 0) * 9 / 16) }
    /// How far apart the middle of two cards is: the half widths of a middle and a side card, and the gap.
    private var stride: CGFloat { max(cardWidth * (1 - sideShrink / 2) + gap, 1) }

    var body: some View {
        ZStack {
            ForEach(slots.indices, id: \.self) { index in
                card(slots[index])
                    .frame(width: cardWidth, height: cardWidth * 16 / 9)
                    .modifier(
                        TripRecapShareCarouselEffect(
                            position: position, index: index, count: slots.count,
                            stride: stride, sideShrink: sideShrink
                        )
                    )
                    .onTapGesture { Move(to: looping.Target(for: index, from: position)) }
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
        .contentShape(.rect)
        .gesture(drag)
        .onChange(of: selectedIndex) { _, newIndex in
            // A change from outside (the dots) moves the cards; a swipe has already moved them.
            guard OptionIndex(atSlot: looping.NearestIndex(to: position)) != newIndex else { return }
            Move(to: NearestTarget(forOption: newIndex))
        }
        .task { await Nudge() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Picture style"))
        .accessibilityValue(Text(options[selectedIndex].format.title))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: Move(to: position.rounded() + 1)
            case .decrement: Move(to: position.rounded() - 1)
            @unknown default: break
            }
        }
    }

    private func card(_ option: TripRecapShareOption) -> some View {
        option.image.previewImage
            .resizable()
            .scaledToFit()
            .background { TripRecapShareCheckerboard() }
            .clipShape(.rect(cornerRadius: 28))
            .accessibilityHidden(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let start = dragStartPosition ?? position
                dragStartPosition = start
                position = start - Double(value.translation.width / stride)
            }
            .onEnded { value in
                let start = dragStartPosition ?? position
                dragStartPosition = nil
                let velocity = -Double(value.velocity.width / stride)
                Move(to: looping.RestingPosition(from: start, releasedAt: position, velocity: velocity))
            }
    }

    /// Slides the cards to `target` and tells the parent which card is now in the middle. With Reduce Motion on,
    /// the cards switch without sliding.
    private func Move(to target: Double) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.38)) { position = target }
        let index = OptionIndex(atSlot: looping.NearestIndex(to: target))
        if selectedIndex != index { selectedIndex = index }
    }

    private func OptionIndex(atSlot slot: Int) -> Int {
        slot % options.count
    }

    /// The position of the closest slot that shows option `index`.
    private func NearestTarget(forOption index: Int) -> Double {
        let targets = slots.indices
            .filter { OptionIndex(atSlot: $0) == index }
            .map { looping.Target(for: $0, from: position) }
        return targets.min { abs($0 - position) < abs($1 - position) } ?? position
    }

    /// Slides the cards a little to the left and back, once, to show that they can be swiped.
    private func Nudge() async {
        guard !reduceMotion, options.count > 1 else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard position == 0 else { return }
        withAnimation(.easeOut(duration: 0.24)) { position = nudgePosition }
        try? await Task.sleep(for: .milliseconds(480))
        guard position == nudgePosition else { return }
        withAnimation(.easeOut(duration: 0.38)) { position = 0 }
    }
}

/// Places one card by its distance from the middle. It is `Animatable` in `position`, so that while the cards slide
/// every frame is worked out again: a card that goes past the end fades out before it jumps to the other side, and
/// nobody sees the jump.
private struct TripRecapShareCarouselEffect: ViewModifier, Animatable {
    var position: Double
    let index: Int
    let count: Int
    let stride: CGFloat
    let sideShrink: Double

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let offset = LoopingPosition(count: count).Offset(of: index, from: position)
        let distance = abs(offset)
        let fadeAtTheEnds = distance > 1 ? max(0, 1 - (distance - 1) * 2) : 1
        content
            .scaleEffect(1 - sideShrink * min(1, distance))
            .opacity((1 - 0.5 * min(1, distance)) * fadeAtTheEnds)
            .offset(x: offset * stride)
            .zIndex(10 - distance * 3)
    }
}

/// The dots under the carousel: a long one for the picture in the middle. Each dot is a button for its format.
struct TripRecapShareDots: View {
    let options: [TripRecapShareOption]
    let selectedIndex: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    select(index)
                } label: {
                    Capsule()
                        .fill(index == selectedIndex ? Color(.brandYellow) : Color.white.opacity(0.3))
                        .frame(width: index == selectedIndex ? 22 : 8, height: 8)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(options[index].format.title))
            }
        }
        .animation(.easeOut(duration: 0.25), value: selectedIndex)
    }
}

/// Light and dark grey squares, the usual way to show that a picture is see-through.
struct TripRecapShareCheckerboard: View {
    private let squareSize: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns {
                    let isLight = (row + column).isMultiple(of: 2)
                    let square = CGRect(
                        x: CGFloat(column) * squareSize, y: CGFloat(row) * squareSize,
                        width: squareSize, height: squareSize
                    )
                    context.fill(Path(square), with: .color(isLight ? Color(white: 0.30) : Color(white: 0.24)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
