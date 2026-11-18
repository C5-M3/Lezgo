//
//  TripMapOnTheGoView.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

/// What the phone shows instead of the trip map while CarPlay is connected: the car's screen has the map, so the
/// phone lists the time to the next stop and every participant. The leader can end the trip or edit the route; a
/// member can exit (ADR 0034).
struct TripMapOnTheGoView: View {
    let viewModel: TripMapViewModel

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `true` once the list has scrolled far enough for the card's label to reach the bar, which then takes the title
    /// over.
    @State private var showsTitleInBar = false
    /// The height of the status bar and the Dynamic Island, read outside the navigation bar: the list starts just under
    /// it, and the empty navigation bar takes no room above the card.
    @State private var statusBarHeight = 0.0

    /// How far the list scrolls before the title moves from the card to the navigation bar, in points.
    private static let titleScrollDistance = 24.0

    /// "To Alun Alun Malang"; the plain label until the route is known.
    private var nextStopTitle: String {
        viewModel.nextStopTitle ?? String(localized: .tripMapOnTheGoNextStop)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    NextStopCard()
                    Text(.tripMapOnTheGoParticipants)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 3)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(viewModel.participantRows) { row in
                        TripMapOnTheGoRow(row: row)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, statusBarHeight + 8)
                // Room for the buttons, so the last row can be scrolled above them.
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            // Under the navigation bar too, so the card starts at the top; the bar shows its background only once
            // rows scroll beneath it.
            .ignoresSafeArea(.container, edges: .top)
            .background(Color(.tripCard).ignoresSafeArea())
            // The system bar centres the title and slides the content under it; the title is only shown once the card,
            // which carries it, has scrolled up to the bar. `navigationTitle` stays for VoiceOver.
            .navigationTitle(nextStopTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(verbatim: nextStopTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .opacity(showsTitleInBar ? 1 : 0)
                }
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            // At rest the card sits where the bar is, so the edge effect would dim it; it comes with the title.
            .scrollEdgeEffectStyle(.hard, for: .top)
            .scrollEdgeEffectHidden(showsTitleInBar == false, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > Self.titleScrollDistance
            } action: { _, isScrolled in
                withAnimation(Animation.lezgoFade.Respecting(reduceMotion: reduceMotion)) {
                    showsTitleInBar = isScrolled
                }
            }
            .overlay(alignment: .bottom) {
                // The rows fade out under the buttons, as in the hi-fi.
                LinearGradient(colors: [.clear, Color(.tripCard)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) { Buttons() }
        }
        .onGeometryChange(for: Double.self, of: { Double($0.safeAreaInsets.top) }, action: { statusBarHeight = $0 })
        .task { await viewModel.TrackAllCars() }
    }

    private func NextStopCard() -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: nextStopTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if let timeToNextStop = viewModel.timeToNextStop {
                    Text(timeToNextStop.formatted(TripMapCarStatus.durationStyle))
                        .font(.system(size: timeSize, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            TripMapOnTheGoTrack(progress: viewModel.routeProgress)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .lezgoSurface(.page, radius: LezgoRadius.card)
        .overlay {
            RoundedRectangle(cornerRadius: LezgoRadius.card)
                .strokeBorder(Color(.surfaceSeparator), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func Buttons() -> some View {
        HStack(spacing: 12) {
            TripMapLeaveButton(isLeader: viewModel.isLeader, action: viewModel.RequestLeave)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isLeaving)
            if viewModel.canEditRoute {
                Button(action: viewModel.RequestEditRoute) {
                    Text(.tripMapEditRoute)
                }
                .lezgoGlassButton(.main)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
