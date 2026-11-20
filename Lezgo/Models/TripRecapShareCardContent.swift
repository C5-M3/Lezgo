//
//  TripRecapShareCardContent.swift
//  Lezgo
//

import Foundation

/// The words and the leader's robot on the trip recap picture that is shared (From, To, Time, Distance).
/// It reads the same resolved values as the detail screen, so the picture never disagrees with the screen.
struct TripRecapShareCardContent: Equatable {
    let dateText: String
    let fromText: String
    /// The destination, with "+N Dest." after it when the trip had stops.
    let toText: String
    let timeText: String
    let distanceText: String
    let leaderAvatar: Avatar
    /// The date as day.month.year with dots, for the dark posters.
    let numericDateText: String
    /// The distance split into the number ("60") and its unit ("km"), so the number can be drawn huge.
    let distanceNumberText: String
    let distanceUnitText: String
    /// "3 cars" and "6 stops".
    let carsText: String
    let stopsText: String
    /// Only the number of stops, for a column of numbers.
    let stopsNumberText: String
    /// "Universitas Ciputra → Tunjungan Plaza": no stop count.
    let routeText: String
    /// The robots of the participants, leader first, at most `maxRobots`; the rest are counted in `hiddenRobotCount`.
    let robots: [Avatar]
    let hiddenRobotCount: Int

    static let maxRobots = 6

    init(recap: TripRecap) {
        dateText = recap.formattedDate
        fromText = recap.resolvedStartPointName
        toText = recap.resolvedStopsCount > 0
            ? "\(recap.destinationName) +\(recap.resolvedStopsCount) Dest."
            : recap.destinationName
        timeText = recap.resolvedDurationText
        distanceText = recap.distanceText
        leaderAvatar = recap.resolvedParticipants.first(where: \.isLeader)?.avatar ?? recap.avatars.first ?? .yellow

        numericDateText = recap.date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .defaultDigits)",
                locale: Locale(identifier: "en_US"),
                timeZone: .current,
                calendar: .current
            )
        )
        (distanceNumberText, distanceUnitText) = Self.SplitDistance(recap.distanceText)
        carsText = recap.participantCount == 1 ? "1 car" : "\(recap.participantCount) cars"
        stopsText = recap.resolvedStopsCount == 1 ? "1 stop" : "\(recap.resolvedStopsCount) stops"
        stopsNumberText = "\(recap.resolvedStopsCount)"
        routeText = "\(recap.resolvedStartPointName) → \(recap.destinationName)"
        let allRobots = recap.resolvedParticipants.map(\.avatar)
        robots = Array(allRobots.prefix(Self.maxRobots))
        hiddenRobotCount = max(0, allRobots.count - Self.maxRobots)
    }

    /// "60 km" becomes ("60", "km"). Text that does not start with a number is kept whole, with no unit.
    private static func SplitDistance(_ text: String) -> (number: String, unit: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let numberEnd = trimmed.firstIndex { !($0.isNumber || $0 == "." || $0 == ",") } ?? trimmed.endIndex
        let number = String(trimmed[..<numberEnd])
        guard !number.isEmpty else { return (trimmed, "") }
        return (number, String(trimmed[numberEnd...]).trimmingCharacters(in: .whitespaces))
    }
}
