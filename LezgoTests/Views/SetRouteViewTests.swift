//
//  SetRouteViewTests.swift
//  LezgoTests
//
//  Created by oky faishal on 10/11/26.
//

import SwiftUI
import Testing
@testable import Lezgo

@MainActor
struct SetRouteViewTests {
    /// #292: Edit Route saves through its own view model, so the planner is told it is saving.
    @Test func SaveShowsProgressWhileTheRouteIsSaving() {
        #expect(SetRouteView(isSaving: true).isShowingSaveProgress)
        #expect(SetRouteView().isShowingSaveProgress == false)
    }

    /// Set Route is built hidden on Home ahead of time, and its map's user dot makes MapKit start the GPS. The GPS
    /// and the dot are wanted only while the screen is shown with the app in front.
    @Test(arguments: [
        (isShown: true, scenePhase: ScenePhase.active, wants: true),
        (isShown: false, scenePhase: ScenePhase.active, wants: false),
        (isShown: true, scenePhase: ScenePhase.inactive, wants: false),
        (isShown: true, scenePhase: ScenePhase.background, wants: false)
    ])
    func LocationIsWantedOnlyWhileShownInFront(isShown: Bool, scenePhase: ScenePhase, wants: Bool) {
        #expect(SetRouteView.WantsLocation(isShown: isShown, scenePhase: scenePhase) == wants)
    }
}
