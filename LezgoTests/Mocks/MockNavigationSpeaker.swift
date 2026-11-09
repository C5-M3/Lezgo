//
//  MockNavigationSpeaker.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
@testable import Lezgo

/// Records what the trip map would say, without playing any audio.
final class MockNavigationSpeaker: NavigationSpeaker {
    private(set) var announcements: [TripMapAnnouncer.Announcement] = []
    private(set) var stopCount = 0

    func Announce(_ announcement: TripMapAnnouncer.Announcement) {
        announcements.append(announcement)
    }

    func Stop() {
        stopCount += 1
    }
}
