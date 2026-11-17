//
//  TripRecapService.swift
//  Lezgo
//
//  Created by Rizal Pratama on 16/11/26.
//

import CloudKit
import Foundation

/// Protokol layanan untuk mengambil riwayat perjalanan dari remote (CloudKit) atau sumber data lain.
protocol TripRecapService: Sendable {
    func fetchRecaps() async throws -> [TripRecap]
}

/// Implementasi `TripRecapService` yang mengambil riwayat trip yang telah selesai dari CloudKit database.
final class CloudKitTripRecapService: TripRecapService, @unchecked Sendable {
    private let database: any CloudDatabase
    private let reader: TripRecordReader

    init(database: any CloudDatabase) {
        self.database = database
        self.reader = TripRecordReader(database: database)
    }

    @MainActor
    convenience init() {
        self.init(database: LiveCloudDatabase())
    }

    func fetchRecaps() async throws -> [TripRecap] {
        var tripIDs: [UUID] = []

        // 1. Ambil trip yang diikuti oleh pengguna saat ini dari record Participant
        let userRecordName: String?
        do {
            userRecordName = try await database.CurrentUserRecordName()
        } catch let ckError as CKError where ckError.code == .notAuthenticated {
            userRecordName = nil
        }

        if let userRecordName {
            let participantRecords = try await database.Query(
                recordType: TripRecordMapper.participantType,
                matching: ["userRecordID": userRecordName]
            )
            tripIDs = participantRecords.compactMap { record in
                guard let reference = record["tripID"] as? CKRecord.Reference else { return nil }
                return UUID(uuidString: reference.recordID.recordName)
            }
        }

        // 2. Jika tidak ada record partisipan khusus (misal di simulator / anonymous),
        // cari trip dengan status ENDED langsung dari database.
        if tripIDs.isEmpty {
            do {
                let endedTripRecords = try await database.Query(
                    recordType: TripRecordMapper.tripType,
                    matching: ["status": TripStatus.ended.rawValue]
                )
                tripIDs = endedTripRecords.compactMap { record in
                    UUID(uuidString: record.recordID.recordName)
                }
            } catch {
                // Fallback pencarian semua trip jika query status tidak terindeks
                let allTrips = try await database.Query(
                    recordType: TripRecordMapper.tripType,
                    matching: [:]
                )
                tripIDs = allTrips.compactMap { record in
                    guard let statusStr = record["status"] as? String,
                          let status = TripStatus(rawValue: statusStr),
                          status == .ended || status == .cancelled else { return nil }
                    return UUID(uuidString: record.recordID.recordName)
                }
            }
        }

        let uniqueTripIDs = Array(Set(tripIDs))
        guard !uniqueTripIDs.isEmpty else { return [] }

        // 3. Muat setiap trip secara paralel menggunakan TaskGroup
        var loadedRecaps: [TripRecap] = []
        await withTaskGroup(of: TripRecap?.self) { group in
            for id in uniqueTripIDs {
                group.addTask { [reader] in
                    do {
                        let state = try await reader.LoadState(tripID: id, loadTrail: false)
                        guard state.trip.status == .ended || state.trip.status == .cancelled else { return nil }
                        return TripRecap(state: state)
                    } catch {
                        return nil
                    }
                }
            }
            for await recap in group {
                if let recap {
                    loadedRecaps.append(recap)
                }
            }
        }

        loadedRecaps.sort { $0.date > $1.date }
        return loadedRecaps
    }
}

/// Adaptor untuk fallback TripRecapService berbasis TripRecapStorage (misal untuk mock / preview)
final class StorageTripRecapService: TripRecapService, @unchecked Sendable {
    private let storage: any TripRecapStorage

    init(storage: any TripRecapStorage) {
        self.storage = storage
    }

    func fetchRecaps() async throws -> [TripRecap] {
        storage.loadRecaps()
    }
}
