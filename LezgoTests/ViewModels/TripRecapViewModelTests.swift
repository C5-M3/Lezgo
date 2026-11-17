//
//  TripRecapViewModelTests.swift
//  LezgoTests
//
//  Created by Rizal Pratama on 16/11/26.
//

import CloudKit
import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRecapViewModelTests {
    private final class MockTripRecapStorage: TripRecapStorage, @unchecked Sendable {
        var items: [TripRecapItem] = []

        func loadRecaps() -> [TripRecapItem] {
            items
        }

        func saveRecap(_ item: TripRecapItem) {
            items.removeAll { $0.id == item.id }
            items.insert(item, at: 0)
        }
    }

    private static let sampleTestRecaps: [TripRecapItem] = [
        TripRecapItem(
            id: UUID(),
            destinationName: "Taman Bungkul",
            destinationLabel: "Taman Bungkul",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            participantCount: 4,
            distanceText: "20 KM",
            avatars: [.yellow, .purple, .pink, .blue],
            startCoordinate: Coordinate(latitude: -7.2891, longitude: 112.7344),
            destinationCoordinate: Coordinate(latitude: -7.2913, longitude: 112.7398),
            polyline: [
                Coordinate(latitude: -7.2891, longitude: 112.7344),
                Coordinate(latitude: -7.2900, longitude: 112.7360),
                Coordinate(latitude: -7.2913, longitude: 112.7398)
            ]
        ),
        TripRecapItem(
            id: UUID(),
            destinationName: "Pakuwon Mall",
            destinationLabel: "Pakuwon Mall",
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            participantCount: 3,
            distanceText: "15 KM",
            avatars: [.yellow, .green, .purple],
            startCoordinate: Coordinate(latitude: -7.2891, longitude: 112.7344),
            destinationCoordinate: Coordinate(latitude: -7.2886, longitude: 112.6756),
            polyline: [
                Coordinate(latitude: -7.2891, longitude: 112.7344),
                Coordinate(latitude: -7.2888, longitude: 112.7000),
                Coordinate(latitude: -7.2886, longitude: 112.6756)
            ]
        )
    ]

    @Test("ViewModel memiliki daftar recaps kosong ketika storage kosong")
    func loadInitialSampleRecaps() {
        let storage = MockTripRecapStorage()
        let viewModel = TripRecapViewModel(storage: storage)

        #expect(viewModel.recaps.isEmpty)
        #expect(viewModel.filteredRecaps.isEmpty)
    }

    @Test("Search query memfilter berdasarkan nama destinasi case-insensitive")
    func searchByDestinationName() {
        let storage = MockTripRecapStorage()
        storage.items = Self.sampleTestRecaps
        let viewModel = TripRecapViewModel(storage: storage)

        viewModel.searchQuery = "bungkul"
        #expect(viewModel.filteredRecaps.count == 1)
        #expect(viewModel.filteredRecaps.first?.destinationName == "Taman Bungkul")

        viewModel.searchQuery = "PAKUWON"
        #expect(viewModel.filteredRecaps.count == 1)
        #expect(viewModel.filteredRecaps.first?.destinationName == "Pakuwon Mall")

        viewModel.searchQuery = "Unknown Location XYZ"
        #expect(viewModel.filteredRecaps.isEmpty)
    }

    @Test("Sort order mengubah urutan daftar riwayat")
    func sortingOrder() {
        let storage = MockTripRecapStorage()
        storage.items = Self.sampleTestRecaps
        let viewModel = TripRecapViewModel(storage: storage)

        viewModel.sortOrder = .newest
        let firstNewest = viewModel.filteredRecaps.first
        #expect(firstNewest?.destinationName == "Taman Bungkul")

        viewModel.sortOrder = .oldest
        let firstOldest = viewModel.filteredRecaps.first
        #expect(firstOldest?.destinationName == "Pakuwon Mall")

        viewModel.sortOrder = .distance
        let firstDistance = viewModel.filteredRecaps.first
        #expect(firstDistance?.distanceText == "20 KM")
    }

    @Test("Menyimpan trip recap baru menambahkannya ke daftar paling atas")
    func saveNewRecap() {
        let storage = MockTripRecapStorage()
        storage.items = Self.sampleTestRecaps
        let viewModel = TripRecapViewModel(storage: storage)

        let newTrip = TripRecapItem(
            id: UUID(),
            destinationName: "Galaxy Mall",
            destinationLabel: "Galaxy Mall 3",
            date: .now,
            participantCount: 3,
            distanceText: "15 KM",
            avatars: [.yellow, .green, .blue],
            startCoordinate: Coordinate(latitude: -7.28, longitude: 112.75),
            destinationCoordinate: Coordinate(latitude: -7.27, longitude: 112.78),
            polyline: [
                Coordinate(latitude: -7.28, longitude: 112.75),
                Coordinate(latitude: -7.27, longitude: 112.78)
            ]
        )

        storage.saveRecap(newTrip)
        viewModel.reload()

        #expect(viewModel.recaps.count == 3)
        #expect(viewModel.recaps.first?.destinationName == "Galaxy Mall")
    }

    @Test("ViewModel memuat data riwayat trip dinamis dari CloudKit")
    func loadRecapsFromCloudKit() async throws {
        let server = FakeCloudServer()
        let database = FakeCloudDatabase(server: server, userRecordName: "_test_user")

        let tripID = UUID()
        let leaderID = UUID()
        let trip = Trip(
            id: tripID,
            roomCode: "123456",
            status: .ended,
            leaderParticipantID: leaderID,
            currentWaypointIndex: 1,
            routeVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            startedAt: Date(timeIntervalSince1970: 1_700_001_000),
            endedAt: Date(timeIntervalSince1970: 1_700_005_000)
        )
        let leader = Participant(
            id: leaderID,
            tripID: tripID,
            userRecordID: "_test_user",
            displayName: "Budi",
            carDescription: "Avanza Hitam",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75),
            speedKmh: 0,
            motionState: .driving,
            alert: .none,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_005_000),
            course: 0,
            wayBack: [],
            avatar: .yellow,
            arrivedAtWaypointID: nil
        )
        let startWaypoint = Waypoint(
            id: UUID(),
            tripID: tripID,
            orderIndex: 0,
            kind: .start,
            name: "Titik Kumpul",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75)
        )
        let destinationWaypoint = Waypoint(
            id: UUID(),
            tripID: tripID,
            orderIndex: 1,
            kind: .destination,
            name: "Grand City Mall",
            coordinate: Coordinate(latitude: -7.26, longitude: 112.76)
        )
        let route = Route(
            id: UUID(),
            tripID: tripID,
            version: 1,
            polyline: [
                Coordinate(latitude: -7.25, longitude: 112.75),
                Coordinate(latitude: -7.26, longitude: 112.76)
            ]
        )

        let tripRecord = TripRecordMapper.MakeRecord(trip)
        let leaderRecord = TripRecordMapper.MakeRecord(leader)
        let startRecord = TripRecordMapper.MakeRecord(startWaypoint)
        let destRecord = TripRecordMapper.MakeRecord(destinationWaypoint)
        let routeRecord = TripRecordMapper.MakeRecord(route)

        try await database.Save(
            [tripRecord, leaderRecord, startRecord, destRecord, routeRecord],
            savePolicy: .allKeys
        )

        let viewModel = TripRecapViewModel(database: database)
        await viewModel.loadRecaps()

        #expect(viewModel.recaps.count == 1)
        #expect(viewModel.recaps.first?.destinationName == "Grand City Mall")
        #expect(viewModel.recaps.first?.participantCount == 1)
        #expect(viewModel.recaps.first?.avatars == [.yellow])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("CloudKit error menghasilkan errorMessage dan fallback ke storage lokal")
    func cloudKitFailureFallback() async {
        let server = FakeCloudServer()
        server.failure = CKError(.networkUnavailable)
        let database = FakeCloudDatabase(server: server, userRecordName: "_test_user")

        let storage = MockTripRecapStorage()
        storage.items = Self.sampleTestRecaps
        let viewModel = TripRecapViewModel(
            recapService: CloudKitTripRecapService(database: database),
            storage: storage
        )

        await viewModel.loadRecaps()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.recaps.count == 2)
    }

    @Test("UserDefaultsTripRecapStorage mengembalikan array kosong ketika storage kosong")
    func userDefaultsEmptyStorage() {
        let testSuiteName = "TestUserDefaults_\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: testSuiteName) else { return }
        defer { userDefaults.removePersistentDomain(forName: testSuiteName) }

        let storage = UserDefaultsTripRecapStorage(userDefaults: userDefaults, storageKey: "test_key")
        #expect(storage.loadRecaps().isEmpty)
    }

    @Test("Avatar mendukung inisialisasi case-insensitive dari string")
    func avatarCaseInsensitiveParsing() {
        #expect(Avatar(caseInsensitive: "yellow") == .yellow)
        #expect(Avatar(caseInsensitive: "Yellow") == .yellow)
        #expect(Avatar(caseInsensitive: "YELLOW") == .yellow)
        #expect(Avatar(caseInsensitive: "blue") == .blue)
        #expect(Avatar(caseInsensitive: "Blue") == .blue)
        #expect(Avatar(caseInsensitive: "pink") == .pink)
        #expect(Avatar(caseInsensitive: "green") == .green)
        #expect(Avatar(caseInsensitive: "purple") == .purple)
        #expect(Avatar(caseInsensitive: "invalid") == nil)
        #expect(Avatar(caseInsensitive: nil) == nil)
    }

    @Test("Participant.Joining menggunakan avatar dari profile jika tersedia")
    func participantJoiningUsesProfileAvatar() {
        let profile = ParticipantProfile(displayName: "Rizal", carDescription: "Civic", avatar: .purple)
        let participant = Participant.Joining(
            tripID: UUID(),
            userRecordID: "user_123",
            profile: profile,
            isLeader: true,
            at: .now
        )
        #expect(participant.avatar == .purple)
    }

    @Test("TripRecap memuat avatar dinamis mengikuti jumlah peserta dan avatar yang digunakan")
    func loadRecapWithMultipleDistinctParticipants() async throws {
        let server = FakeCloudServer()
        let database = FakeCloudDatabase(server: server, userRecordName: "_leader_user")

        let tripID = UUID()
        let leaderID = UUID()
        let member1ID = UUID()
        let member2ID = UUID()

        let trip = Trip(
            id: tripID,
            roomCode: "654321",
            status: .ended,
            leaderParticipantID: leaderID,
            currentWaypointIndex: 1,
            routeVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            startedAt: Date(timeIntervalSince1970: 1_700_001_000),
            endedAt: Date(timeIntervalSince1970: 1_700_005_000)
        )
        let leader = Participant(
            id: leaderID,
            tripID: tripID,
            userRecordID: "_leader_user",
            displayName: "Leader",
            carDescription: "Car 1",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75),
            speedKmh: 0,
            motionState: .driving,
            alert: .none,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_005_000),
            course: 0,
            wayBack: [],
            avatar: .yellow,
            arrivedAtWaypointID: nil
        )
        let member1 = Participant(
            id: member1ID,
            tripID: tripID,
            userRecordID: "_member_1",
            displayName: "Member 1",
            carDescription: "Car 2",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75),
            speedKmh: 0,
            motionState: .driving,
            alert: .none,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_005_000),
            course: 0,
            wayBack: [],
            avatar: .pink,
            arrivedAtWaypointID: nil
        )
        let member2 = Participant(
            id: member2ID,
            tripID: tripID,
            userRecordID: "_member_2",
            displayName: "Member 2",
            carDescription: "Car 3",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75),
            speedKmh: 0,
            motionState: .driving,
            alert: .none,
            lastSeenAt: Date(timeIntervalSince1970: 1_700_005_000),
            course: 0,
            wayBack: [],
            avatar: .blue,
            arrivedAtWaypointID: nil
        )
        let startWaypoint = Waypoint(
            id: UUID(),
            tripID: tripID,
            orderIndex: 0,
            kind: .start,
            name: "Titik Kumpul",
            coordinate: Coordinate(latitude: -7.25, longitude: 112.75)
        )
        let destinationWaypoint = Waypoint(
            id: UUID(),
            tripID: tripID,
            orderIndex: 1,
            kind: .destination,
            name: "Galaxy Mall Surabaya",
            coordinate: Coordinate(latitude: -7.26, longitude: 112.76)
        )
        let route = Route(
            id: UUID(),
            tripID: tripID,
            version: 1,
            polyline: [
                Coordinate(latitude: -7.25, longitude: 112.75),
                Coordinate(latitude: -7.26, longitude: 112.76)
            ]
        )

        let records = [
            TripRecordMapper.MakeRecord(trip),
            TripRecordMapper.MakeRecord(leader),
            TripRecordMapper.MakeRecord(member1),
            TripRecordMapper.MakeRecord(member2),
            TripRecordMapper.MakeRecord(startWaypoint),
            TripRecordMapper.MakeRecord(destinationWaypoint),
            TripRecordMapper.MakeRecord(route)
        ]

        try await database.Save(records, savePolicy: .allKeys)

        let viewModel = TripRecapViewModel(database: database)
        await viewModel.loadRecaps()

        #expect(viewModel.recaps.count == 1)
        guard let recap = viewModel.recaps.first else {
            Issue.record("Recap harus berhasil dimuat")
            return
        }
        #expect(recap.participantCount == 3)
        #expect(recap.avatars.first == .yellow)
        #expect(Set(recap.avatars) == Set([.yellow, .pink, .blue]))
    }
}
