//
//  HomeSplitStage.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// The split-screen Home (issue #329): a yellow LEAD half on top of a dark JOIN half, the two halves as buttons, and
/// Set Route or Enter room code wiping in over them. Everything moves with `progress`, which the caller animates.
struct HomeSplitStage<LeadScreen: View, JoinScreen: View>: View {
    let flow: HomeSplitMotion.Flow
    let progress: Double
    /// The screen that covers part or all of Home, if any.
    let destination: HomeSplitMotion.Flow?
    let onLead: () -> Void
    let onJoin: () -> Void
    let leadScreen: LeadScreen
    let joinScreen: JoinScreen

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var canvas = CGSize(width: HomeSplitMotion.canvasWidth, height: HomeSplitMotion.canvasHeight)

    init(
        flow: HomeSplitMotion.Flow,
        progress: Double,
        destination: HomeSplitMotion.Flow?,
        onLead: @escaping () -> Void,
        onJoin: @escaping () -> Void,
        @ViewBuilder leadScreen: () -> LeadScreen,
        @ViewBuilder joinScreen: () -> JoinScreen
    ) {
        self.flow = flow
        self.progress = progress
        self.destination = destination
        self.onLead = onLead
        self.onJoin = onJoin
        self.leadScreen = leadScreen()
        self.joinScreen = joinScreen()
    }

    /// On the JOIN home the split line sits higher, so the tap areas follow it.
    private var isOnJoinHome: Bool {
        flow == .join && progress > 0
    }

    var body: some View {
        // Home is drawn behind the destinations, so it never sets their size: it fills the whole screen at its
        // design size, while Set Route and Enter room code keep the safe area and the space above the keyboard. As
        // siblings in one stack, Home made the stack taller than that space and the keyboard pushed Enter room code
        // up under the clock.
        destinations
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { home }
    }

    private var home: some View {
        ZStack(alignment: .topLeading) {
            HomeSplitHalf(look: .dark, flow: flow, progress: progress, canvas: canvas)

            HomeSplitHalf(look: .yellowLead, flow: flow, progress: progress, canvas: canvas)
                .clipShape(HomeSplitShape(part: .topSlab, flow: flow, progress: progress))

            HomeSplitHalf(look: .yellowJoin, flow: flow, progress: progress, canvas: canvas)
                .clipShape(HomeSplitShape(part: .bottomSlab, flow: flow, progress: progress))

            if destination == nil {
                HalfButton(
                    title: "Lead a trip",
                    hint: "Plan the trip and make a room for friends to join trip!",
                    area: Area(isOnJoinHome ? .overBottomSlab : .topSlab),
                    action: onLead
                )
                HalfButton(
                    title: "Join a trip",
                    hint: "Got a room code from friend leader? Join the room now!",
                    area: Area(isOnJoinHome ? .bottomSlab : .underTopSlab),
                    action: onJoin
                )
            }
        }
        // With Reduce Motion the halves jump to their new place while the next screen fades.
        .transaction(value: progress) { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // Measured over the whole screen, the safe area included, which the design is drawn on.
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { canvas = $0 }
        }
        .ignoresSafeArea()
    }

    private func Area(_ part: HomeSplitShape.Part) -> HomeSplitShape {
        HomeSplitShape(part: part, flow: flow, progress: progress)
    }

    private var destinations: some View {
        ZStack {
            if destination == .lead {
                leadScreen
                    .modifier(HomeSplitWipe(flow: .lead, progress: progress, canvasHeight: canvas.height))
                    .transition(.homeSplitWipe(.lead, canvasHeight: canvas.height, reduceMotion: reduceMotion))
            }
            if destination == .join {
                joinScreen
                    .modifier(HomeSplitWipe(flow: .join, progress: progress, canvasHeight: canvas.height))
                    .transition(.homeSplitWipe(.join, canvasHeight: canvas.height, reduceMotion: reduceMotion))
            }
        }
    }
}

/// A half of the split Home as one large button, shaped like the half so a tap lands where the eye expects it.
private struct HalfButton: View {
    let title: LocalizedStringResource
    let hint: LocalizedStringResource
    let area: HomeSplitShape
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .contentShape(area)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(hint))
    }
}

#Preview("LEAD home") {
    HomeSplitStage(
        flow: .lead,
        progress: 0,
        destination: nil,
        onLead: {},
        onJoin: {},
        leadScreen: { EmptyView() },
        joinScreen: { EmptyView() }
    )
}

#Preview("JOIN home") {
    HomeSplitStage(
        flow: .join,
        progress: HomeSplitMotion.joinHome,
        destination: nil,
        onLead: {},
        onJoin: {},
        leadScreen: { EmptyView() },
        joinScreen: { EmptyView() }
    )
}
