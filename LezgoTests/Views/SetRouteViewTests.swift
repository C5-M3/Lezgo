//
//  SetRouteViewTests.swift
//  LezgoTests
//
//  Created by oky faishal on 10/11/26.
//

import Testing
@testable import Lezgo

@MainActor
struct SetRouteViewTests {
    /// #292: Edit Route saves through its own view model, so the planner is told it is saving.
    @Test func SaveShowsProgressWhileTheRouteIsSaving() {
        #expect(SetRouteView(isSaving: true).isShowingSaveProgress)
        #expect(SetRouteView().isShowingSaveProgress == false)
    }
}
