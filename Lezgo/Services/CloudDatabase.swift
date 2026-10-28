//
//  CloudDatabase.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import CloudKit
import Foundation

/// The few CloudKit public-database calls `LiveTripService` needs.
///
/// `LiveCloudDatabase` talks to iCloud. Tests use a fake, so every `LiveTripService` rule is tested without a
/// network or an iCloud account. Errors are CloudKit's own (`CKError`); `LiveTripService` turns them into
/// `TripServiceError`.
@MainActor
protocol CloudDatabase {
    /// The record name of this phone's iCloud user. Throws `CKError.notAuthenticated` when not signed in.
    func CurrentUserRecordName() async throws -> String

    /// The record with this ID. Throws `CKError.unknownItem` when it does not exist.
    func Fetch(_ recordID: CKRecord.ID) async throws -> CKRecord

    /// The records with these IDs that still exist, in one request. Missing records are left out, not an error.
    func Fetch(_ recordIDs: [CKRecord.ID]) async throws -> [CKRecord]

    /// Every record of this type whose fields equal all the given values. A reference matches by record ID.
    func Query(recordType: String, matching conditions: [String: any CKRecordValueProtocol]) async throws -> [CKRecord]

    /// Saves the records. With `.ifServerRecordUnchanged`, a record that changed on the server since it was
    /// fetched fails with `CKError.serverRecordChanged`.
    func Save(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws

    /// Deletes the records. Records that no longer exist are ignored.
    func Delete(_ recordIDs: [CKRecord.ID]) async throws
}
