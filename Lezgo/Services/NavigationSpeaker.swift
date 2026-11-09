//
//  NavigationSpeaker.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation

/// Plays what the trip map says: a spoken turn, or a chime and the text of a new alert (ADR 0024).
///
/// `LiveNavigationSpeaker` uses AVFoundation; tests use `MockNavigationSpeaker`, and previews pass none.
protocol NavigationSpeaker {
    func Announce(_ announcement: TripMapAnnouncer.Announcement)
    /// Stops at once: the person muted the map or left the trip.
    func Stop()
}
