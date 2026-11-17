//
//  HomeSplitStage.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// The split-screen Home (issue #329): a yellow LEAD half on top of a dark JOIN half, the two halves as buttons, and
/// Set Route or Enter room code wiping in over them. Everything moves with `progress`, which the caller animates.
/// Set Route can be built ahead while Home is idle and kept hidden and inert, so building its map never stalls the
/// motion.
struct HomeSplitStage<LeadScreen: View, JoinScreen: View>: View {
    let flow: HomeSplitMotion.Flow
    let progress: Double
    /// The screen that covers part or all of Home, if any.
    let destination: HomeSplitMotion.Flow?
    /// `true` while the motion runs; Home must stay drawn then, even under a screen that covers it.
    let isMoving: Bool
    /// Where the running step started; a screen added as the step starts wipes in from there.
    let stepStart: Double
    /// `true` once Set Route should be built: it then stays in place, hidden until LEAD brings it in.
    let preparesLeadScreen: Bool
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
        isMoving: Bool = false,
        stepStart: Double = 0,
        preparesLeadScreen: Bool = false,
        onLead: @escaping () -> Void,
        onJoin: @escaping () -> Void,
        @ViewBuilder leadScreen: () -> LeadScreen,
        @ViewBuilder joinScreen: () -> JoinScreen
    ) {
        self.flow = flow
        self.progress = progress
        self.destination = destination
        self.isMoving = isMoving
        self.stepStart = stepStart
        self.preparesLeadScreen = preparesLeadScreen
        self.onLead = onLead
        self.onJoin = onJoin
        self.leadScreen = leadScreen()
        self.joinScreen = joinScreen()
    }

    private var isCovered: Bool {
        destination != nil && !isMoving
    }

    /// On the JOIN home the split line sits higher, so the tap areas follow it. Every flow is on the LEAD home at 0.
    private var isOnJoinHome: Bool {
        progress > 0
    }

    var body: some View {
        // Home is drawn behind the destinations, so it never sets their size: it fills the whole screen at its
        // design size, while Set Route and Enter room code keep the safe area and the space above the keyboard. As
        // siblings in one stack, Home made the stack taller than that space and the keyboard pushed Enter room code
        // up under the clock.
        destinations
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The whole screen, which the design is drawn on: the safe area plus its insets. The keyboard only moves
            // space from the one to the other, so Home keeps its size while it shows.
            .onGeometryChange(for: CGSize.self) { proxy in
                let insets = proxy.safeAreaInsets
                return CGSize(
                    width: proxy.size.width + insets.leading + insets.trailing,
                    height: proxy.size.height + insets.top + insets.bottom
                )
            } action: { canvas = $0 }
            .background(alignment: .topLeading) {
                // Hidden once a screen covers it: the keyboard is see-through and would show Home under Enter room
                // code. The change never animates, so it cannot fade Home in or out during the motion.
                home.animation(nil) { $0.opacity(isCovered ? 0 : 1) }
            }
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
                    // A tap on the dark half only brings it to the front, so its hint says so.
                    hint: isOnJoinHome
                        ? "Brings Lead a trip to the front."
                        : "Plan the trip and make a room for friends to join trip!",
                    area: Area(isOnJoinHome ? .overBottomSlab : .topSlab),
                    action: onLead
                )
                HalfButton(
                    title: "Join a trip",
                    hint: !isOnJoinHome
                        ? "Brings Join a trip to the front."
                        : "Got a room code from friend leader? Join the room now!",
                    area: Area(isOnJoinHome ? .bottomSlab : .underTopSlab),
                    action: onJoin
                )
            }
        }
        // With Reduce Motion the halves jump to their new place while the next screen fades.
        .transaction(value: progress) { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .ignoresSafeArea()
    }

    private func Area(_ part: HomeSplitShape.Part) -> HomeSplitShape {
        HomeSplitShape(part: part, flow: flow, progress: progress)
    }

    private var destinations: some View {
        ZStack {
            if preparesLeadScreen || destination == .lead {
                Destination(.lead, leadScreen)
            }
            if destination == .join {
                Destination(.join, joinScreen)
            }
        }
    }

    /// The next screen, wiped in with the motion. It is on screen for the whole run that brings it in or takes it
    /// away, and takes taps, VoiceOver and the keyboard only once it has landed. A screen built ahead stays hidden
    /// and inert until its run.
    private func Destination(_ screenFlow: HomeSplitMotion.Flow, _ screen: some View) -> some View {
        let isOn = destination == screenFlow
        return screen
            .environment(\.canRaiseKeyboard, isOn && !isMoving)
            .modifier(
                HomeSplitWipe(
                    flow: screenFlow,
                    progress: progress,
                    canvasHeight: canvas.height,
                    isWiping: !reduceMotion
                )
            )
            // The wipe shows and hides it; the change of `isOn` never animates, except as a fade with Reduce Motion.
            .animation(reduceMotion ? .lezgoFade : nil) { $0.opacity(isOn ? 1 : 0) }
            .allowsHitTesting(isOn && !isMoving)
            .accessibilityHidden(!isOn)
            // While hidden it keeps its size when the keyboard comes or goes over another screen, so it is not laid
            // out again in the middle of a motion.
            .ignoresSafeArea(isOn && screenFlow == .lead ? [] : .keyboard)
            .transition(
                .homeSplitWipe(screenFlow, from: stepStart, canvasHeight: canvas.height, reduceMotion: reduceMotion)
            )
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
