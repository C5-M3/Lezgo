//
//  TripMapAnnouncer.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation

/// Decides what the trip map says out loud: the next turn at about 500 m, 200 m and at the turn, a chime and the text
/// of each new alert, and a short word about a new route (`specs/UserStories.md` → US-06, "Sound",
/// ADR 0024). It only decides; a `NavigationSpeaker` plays it, so the rules are tested without audio.
struct TripMapAnnouncer {
    /// The turn being announced and how much of it has been said.
    private var turn: Turn?
    /// Banners and notices already announced. Each is announced once while it stays; once nothing is shown, it can
    /// be announced again when it happens again.
    private var announcedBanners: Set<TripMapAlerts.Banner> = []
    private var announcedNotices: Set<TripMapNotice> = []

    /// A turn further than this when first seen gets the early call.
    private static let earlyCallMeters = 500.0
    private static let nearCallMeters = 200.0
    private static let atTurnMeters = 30.0
    /// The same instruction this much further away than before is the next turn, not GPS noise.
    private static let nextTurnJumpMeters = 100.0

    private struct Turn {
        let instruction: String
        let direction: TripMapGuidance.TurnDirection
        let firstSeenMeters: Double
        var lastMeters = 0.0
        var stagesSaid: Set<Stage> = []
    }

    private enum Stage {
        case early
        case near
        case atTurn

        /// The calls this one makes unnecessary, itself included.
        var andEarlier: Set<Self> {
            switch self {
            case .early: [.early]
            case .near: [.early, .near]
            case .atTurn: [.early, .near, .atTurn]
            }
        }
    }

    /// What to say after the trip map changed, in order: the alert first, then a route change, then the turn.
    mutating func Update(
        guidance: TripMapGuidance?,
        banner: TripMapAlerts.Banner?,
        notice: TripMapNotice?
    ) -> [Announcement] {
        [Announce(banner), Announce(notice), Announce(guidance)].compactMap(\.self)
    }

    private mutating func Announce(_ banner: TripMapAlerts.Banner?) -> Announcement? {
        guard let banner else {
            announcedBanners.removeAll()
            return nil
        }
        guard announcedBanners.insert(banner).inserted else { return nil }
        return .alert(message: String(localized: banner.message))
    }

    private mutating func Announce(_ notice: TripMapNotice?) -> Announcement? {
        guard let notice else {
            announcedNotices.removeAll()
            return nil
        }
        guard announcedNotices.insert(notice).inserted else { return nil }
        return notice.isUrgent ? .alert(message: notice.Message(timeLeft: nil)) : .routeChanged(notice)
    }

    private mutating func Announce(_ guidance: TripMapGuidance?) -> Announcement? {
        guard let guidance else { return nil }
        let meters = guidance.distanceToTurn.converted(to: .meters).value
        if IsNextTurn(guidance, meters: meters) {
            turn = Turn(instruction: guidance.instruction, direction: guidance.direction, firstSeenMeters: meters)
        }
        turn?.lastMeters = meters
        guard let current = turn, let stage = DueStage(at: meters, of: current),
              current.stagesSaid.contains(stage) == false else { return nil }
        // A later call covers the earlier ones: a turn first seen at 150 m never says "In 500 metres".
        turn?.stagesSaid.formUnion(stage.andEarlier)
        let roundedMeters = stage == .atTurn ? nil : Int((meters / 50).rounded()) * 50
        return .turn(instruction: guidance.instruction, meters: roundedMeters)
    }

    /// A different instruction, or the same one much further away than before, is the next turn.
    private func IsNextTurn(_ guidance: TripMapGuidance, meters: Double) -> Bool {
        guard let turn else { return true }
        return turn.instruction != guidance.instruction
            || turn.direction != guidance.direction
            || meters > turn.lastMeters + Self.nextTurnJumpMeters
    }

    /// The call due at this distance, or `nil` while the turn is still far away.
    private func DueStage(at meters: Double, of turn: Turn) -> Stage? {
        if meters <= Self.atTurnMeters { return .atTurn }
        if meters <= Self.nearCallMeters { return .near }
        if meters <= Self.earlyCallMeters, turn.firstSeenMeters > Self.earlyCallMeters { return .early }
        return nil
    }
}

extension TripMapAnnouncer {
    /// One thing the trip map says.
    enum Announcement: Hashable {
        /// The next turn; `meters` is how far it is, rounded to 50 m, or `nil` at the turn itself.
        case turn(instruction: String, meters: Int?)
        /// A new route or changed stops: "New route", "Route updated".
        case routeChanged(TripMapNotice)
        /// A new banner that needs the driver's attention: a chime, then its text.
        case alert(message: String)

        /// Only an alert starts with the chime; a turn or a route change is spoken alone.
        var playsChime: Bool {
            if case .alert = self { return true }
            return false
        }

        /// What is spoken: "In 200 meters, turn right", "Turn right", "New route" or the banner text.
        func SpokenText(locale: Locale = .current) -> String {
            switch self {
            case let .turn(instruction, meters?):
                let distance = Measurement(value: Double(meters), unit: UnitLength.meters)
                    .formatted(.measurement(width: .wide, usage: .asProvided).locale(locale))
                // MapKit's instruction starts with a capital ("Turn right"); it follows the distance here.
                let lowercased = instruction.prefix(1).lowercased(with: locale) + instruction.dropFirst()
                var resource = LocalizedStringResource.tripMapVoiceTurnIn(distance, lowercased)
                resource.locale = locale
                return String(localized: resource)
            case let .turn(instruction, nil):
                return instruction
            case .routeChanged(.routeUpdated):
                return String(localized: .tripMapNoticeRouteUpdated)
            case .routeChanged:
                return String(localized: .tripMapNoticeNewRoute)
            case let .alert(message):
                return message
            }
        }
    }
}
