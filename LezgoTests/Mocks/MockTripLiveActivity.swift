//
//  MockTripLiveActivity.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 12/11/26.
//

import Foundation
@testable import Lezgo

/// Records what the updater asks ActivityKit to do, without showing anything.
final class MockTripLiveActivity: TripLiveActivity {
    enum Call: Equatable {
        case start(title: String, stage: TripActivityAttributes.Stage)
        case update(TripActivityAttributes.ContentState)
        case end
        case endLeftovers
    }

    private(set) var calls: [Call] = []
    /// `false` acts as if the person turned Live Activities off for Lezgo.
    var canStart = true

    func Start(_ attributes: TripActivityAttributes, state: TripActivityAttributes.ContentState) -> Bool {
        calls.append(.start(title: attributes.title, stage: state.stage))
        return canStart
    }

    func Update(_ state: TripActivityAttributes.ContentState) {
        calls.append(.update(state))
    }

    func End() {
        calls.append(.end)
    }

    func EndLeftovers() {
        calls.append(.endLeftovers)
    }
}
