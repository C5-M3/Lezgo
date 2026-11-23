//
//  TripRecap.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import CoreLocation
import Foundation
import MapKit

/// Alias untuk kompatibilitas kode pengujian dan komponen terdahulu.
typealias TripRecapItem = TripRecap

/// Model partisipan dalam riwayat perjalanan.
struct TripRecapParticipant: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var displayName: String
    var carDescription: String
    var avatar: Avatar
    var isLeader: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        carDescription: String = "",
        avatar: Avatar = .yellow,
        isLeader: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.carDescription = carDescription
        self.avatar = avatar
        self.isLeader = isLeader
    }
}

/// Model mewakili ringkasan riwayat perjalanan yang telah diselesaikan.
struct TripRecap: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var destinationName: String
    var destinationLabel: String
    var date: Date
    var participantCount: Int
    var distanceText: String
    var avatars: [Avatar]
    var startCoordinate: Coordinate
    var destinationCoordinate: Coordinate
    var polyline: [Coordinate]

    var startPointName: String?
    var numberOfStops: Int?
    var durationText: String?
    var participants: [TripRecapParticipant]?

    init(
        id: UUID,
        destinationName: String,
        destinationLabel: String,
        date: Date,
        participantCount: Int,
        distanceText: String,
        avatars: [Avatar],
        startCoordinate: Coordinate,
        destinationCoordinate: Coordinate,
        polyline: [Coordinate],
        startPointName: String? = nil,
        numberOfStops: Int? = nil,
        durationText: String? = nil,
        participants: [TripRecapParticipant]? = nil
    ) {
        self.id = id
        self.destinationName = destinationName
        self.destinationLabel = destinationLabel
        self.date = date
        self.participantCount = participantCount
        self.distanceText = distanceText
        self.avatars = avatars
        self.startCoordinate = startCoordinate
        self.destinationCoordinate = destinationCoordinate
        self.polyline = polyline
        self.startPointName = startPointName
        self.numberOfStops = numberOfStops
        self.durationText = durationText
        self.participants = participants
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    var resolvedStartPointName: String {
        if let startPointName, !startPointName.isEmpty {
            return startPointName
        }
        return "Starting Point"
    }

    var resolvedStopsCount: Int {
        numberOfStops ?? 0
    }

    /// "3 people · 60 km", or "1 person · 60 km" for a leader who drove alone (plural rule in the String Catalog).
    var peopleAndDistanceText: LocalizedStringResource {
        "\(participantCount) people · \(distanceText)"
    }

    var resolvedDurationText: String {
        if let durationText, !durationText.isEmpty {
            return durationText
        }
        return "–"
    }

    /// Menghasilkan avatar yang dinamis mengikuti data dari `TripRecap` (`avatars` dan `participantCount`).
    /// Jika jumlah avatar kurang dari jumlah peserta atau jika semua warna seragam,
    /// diberikan variasi warna dinamis dari seluruh koleksi Avatar.
    var dynamicAvatars: [Avatar] {
        var result = avatars

        if result.count < participantCount {
            let allAvatars = Avatar.allCases
            for index in result.count..<participantCount {
                let color = allAvatars[index % allAvatars.count]
                result.append(color)
            }
        }

        if result.count > 1 && Set(result).count == 1 {
            let allAvatars = Avatar.allCases
            result = result.indices.map { index in
                allAvatars[index % allAvatars.count]
            }
        }

        if result.isEmpty {
            result = [.yellow]
        }

        return result
    }

    var resolvedParticipants: [TripRecapParticipant] {
        let dynAvatars = dynamicAvatars
        if let participants, !participants.isEmpty {
            return participants.enumerated().map { index, participant in
                var participantCopy = participant
                if index < dynAvatars.count {
                    participantCopy.avatar = dynAvatars[index]
                } else {
                    let allAvatars = Avatar.allCases
                    participantCopy.avatar = allAvatars[index % allAvatars.count]
                }
                return participantCopy
            }
        }
        let count = max(participantCount, dynAvatars.count, 1)
        var result: [TripRecapParticipant] = []
        let allAvatars = Avatar.allCases
        for index in 0..<count {
            let avatar = index < dynAvatars.count ? dynAvatars[index] : allAvatars[index % allAvatars.count]
            let isLeader = (index == 0)
            let name = isLeader ? "Agus" : (index == 1 ? "Budi" : (index == 2 ? "Citra" : "Member \(index + 1)"))
            result.append(TripRecapParticipant(
                id: UUID(),
                displayName: name,
                carDescription: "",
                avatar: avatar,
                isLeader: isLeader
            ))
        }
        return result
    }

    var boundingRect: MKMapRect {
        var rect: MKMapRect = .null
        for coord in polyline {
            let point = MKMapPoint(coord.locationCoordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        guard !rect.isNull, !rect.isEmpty else {
            let center = MKMapPoint(destinationCoordinate.locationCoordinate)
            return MKMapRect(x: center.x - 5000, y: center.y - 5000, width: 10000, height: 10000)
        }
        let marginX = max(rect.size.width * 0.35, 3000)
        let marginY = max(rect.size.height * 0.35, 3000)
        return rect.insetBy(dx: -marginX, dy: -marginY)
    }
}

extension TripRecap {
    /// Membuat ringkasan perjalanan dari `TripState` CloudKit.
    init?(state: TripState) {
        guard let destination = state.destination else { return nil }
        self.id = state.trip.id
        self.destinationName = destination.name
        self.destinationLabel = destination.name
        self.date = state.trip.endedAt ?? state.trip.startedAt ?? state.trip.createdAt
        self.participantCount = max(state.participants.count, 1)

        let coordinates: [Coordinate]
        if let poly = state.route?.polyline, !poly.isEmpty {
            coordinates = poly
        } else {
            coordinates = state.waypoints.map(\.coordinate)
        }
        self.polyline = coordinates
        self.distanceText = Self.calculateDistance(coordinates: coordinates)

        let sortedParticipants = state.participants.sorted { p1, p2 in
            p1.id == state.trip.leaderParticipantID && p2.id != state.trip.leaderParticipantID
        }
        let participantAvatars = Self.resolveAvatars(for: sortedParticipants)
        self.avatars = participantAvatars

        let startWaypoint = state.waypoints.first(where: { $0.kind == .start })
        let startCoord = startWaypoint?.coordinate
            ?? coordinates.first
            ?? destination.coordinate
        self.startCoordinate = startCoord
        self.destinationCoordinate = destination.coordinate

        self.startPointName = startWaypoint?.name ?? "Starting Point"
        self.numberOfStops = state.waypoints.filter { $0.kind == .checkpoint }.count
        self.durationText = Self.formatDuration(
            startedAt: state.trip.startedAt,
            createdAt: state.trip.createdAt,
            endedAt: state.trip.endedAt
        )

        self.participants = sortedParticipants.enumerated().map { index, participant in
            TripRecapParticipant(
                id: participant.id,
                displayName: state.DisplayName(of: participant),
                carDescription: participant.carDescription,
                avatar: index < participantAvatars.count ? participantAvatars[index] : participant.avatar,
                isLeader: participant.IsLeader(in: state.trip)
            )
        }
    }

    private static func calculateDistance(coordinates: [Coordinate]) -> String {
        var meters: CLLocationDistance = 0
        if coordinates.count > 1 {
            for index in 0..<(coordinates.count - 1) {
                meters += coordinates[index].Distance(to: coordinates[index + 1])
            }
        }
        let km = Int(round(meters / 1000.0))
        if km > 0 {
            return "\(km) km"
        } else if meters > 0 {
            return "< 1 km"
        } else {
            return "0 km"
        }
    }

    private static func formatDuration(startedAt: Date?, createdAt: Date, endedAt: Date?) -> String {
        let startTime = startedAt ?? createdAt
        let endTime = endedAt ?? Date()
        let seconds = max(0, endTime.timeIntervalSince(startTime))
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }

    private static func resolveAvatars(for sortedParticipants: [Participant]) -> [Avatar] {
        var participantAvatars = sortedParticipants.map(\.avatar)
        if participantAvatars.isEmpty {
            participantAvatars = [.yellow]
        }
        if participantAvatars.count > 1 && Set(participantAvatars).count == 1 {
            let allCases = Avatar.allCases
            participantAvatars = participantAvatars.indices.map { index in
                allCases[index % allCases.count]
            }
        }
        return participantAvatars
    }
}

#if DEBUG
extension TripRecap {
    static let sample = TripRecap(
        id: UUID(),
        destinationName: "Tunjungan Plaza",
        destinationLabel: "Tunjungan Plaza",
        date: {
            var components = DateComponents()
            components.year = 2026
            components.month = 10
            components.day = 8
            return Calendar.current.date(from: components) ?? Date()
        }(),
        participantCount: 3,
        distanceText: "60 km",
        avatars: [.yellow, .purple, .pink],
        startCoordinate: Coordinate(latitude: -7.2891, longitude: 112.6326),
        destinationCoordinate: Coordinate(latitude: -7.2622, longitude: 112.7387),
        polyline: [
            Coordinate(latitude: -7.2891, longitude: 112.6326),
            Coordinate(latitude: -7.2850, longitude: 112.6600),
            Coordinate(latitude: -7.2900, longitude: 112.7000),
            Coordinate(latitude: -7.2750, longitude: 112.7200),
            Coordinate(latitude: -7.2622, longitude: 112.7387)
        ],
        startPointName: "Universitas Ciputra",
        numberOfStops: 6,
        durationText: "4h 18m",
        participants: [
            TripRecapParticipant(
                id: UUID(),
                displayName: "Agus",
                carDescription: "White Avanza",
                avatar: .yellow,
                isLeader: true
            ),
            TripRecapParticipant(
                id: UUID(),
                displayName: "Budi",
                carDescription: "Black Brio",
                avatar: .purple,
                isLeader: false
            ),
            TripRecapParticipant(
                id: UUID(),
                displayName: "Citra",
                carDescription: "Red Jazz",
                avatar: .pink,
                isLeader: false
            )
        ]
    )
}
#endif

/// Protokol penyimpanan lokal untuk riwayat trip recap.
protocol TripRecapStorage: Sendable {
    func loadRecaps() -> [TripRecap]
    func saveRecap(_ item: TripRecap)
}

/// Implementasi default UserDefaults untuk menyimpan riwayat trip recap.
final class UserDefaultsTripRecapStorage: TripRecapStorage, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "trip_recaps_history") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func loadRecaps() -> [TripRecap] {
        guard let data = userDefaults.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([TripRecap].self, from: data) else {
            return []
        }
        let realItems = items.filter { item in
            item.destinationName != "Taman Bungkul" && item.destinationName != "Pakuwon Mall"
        }
        if realItems.count != items.count {
            if let cleanData = try? JSONEncoder().encode(realItems) {
                userDefaults.set(cleanData, forKey: storageKey)
            }
        }
        return realItems
    }

    func saveRecap(_ item: TripRecap) {
        var items = loadRecaps()
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        if let data = try? JSONEncoder().encode(items) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
}
