//
//  TripSeat.swift
//  Lezgo
//
//  Created by Oky Faishal on 16/11/26.
//

import CryptoKit
import Foundation

/// Which open trip an iCloud account is in, and which phone holds that place (ADR 0031).
///
/// It is saved as one record per account, so the account is in one trip at a time. The `sessionID` changes each time
/// a phone joins: a phone that finds another `sessionID` in the seat knows another phone took its place.
struct TripSeat: Hashable {
    var tripID: UUID
    var participantID: UUID
    var sessionID: UUID

    /// Three UUIDs of 16 bytes each.
    static let byteCount = 48

    var bytes: Data {
        [tripID, participantID, sessionID].reduce(into: Data()) { data, id in
            withUnsafeBytes(of: id.uuid) { data.append(contentsOf: $0) }
        }
    }

    init(tripID: UUID, participantID: UUID, sessionID: UUID) {
        self.tripID = tripID
        self.participantID = participantID
        self.sessionID = sessionID
    }

    init?(bytes: Data) {
        guard bytes.count == Self.byteCount else { return nil }
        let identifiers = (0..<3).map { index in
            let part = Data(bytes[bytes.startIndex + index * 16..<bytes.startIndex + (index + 1) * 16])
            return UUID(uuid: part.withUnsafeBytes { $0.loadUnaligned(as: uuid_t.self) })
        }
        self.init(tripID: identifiers[0], participantID: identifiers[1], sessionID: identifiers[2])
    }

    /// A short, stable name for an iCloud account that does not show the account: SHA-256 in hexadecimal.
    static func AccountToken(forAccount userRecordName: String) -> String {
        SHA256.hash(data: Data(userRecordName.utf8))
            .map { (($0 < 16) ? "0" : "") + String($0, radix: 16) }
            .joined()
    }

    /// The name of the account's seat record. CloudKit names are ASCII, at most 255 characters, and never start
    /// with an underscore.
    static func RecordName(forAccount userRecordName: String) -> String {
        AccountToken(forAccount: userRecordName) + "-seat"
    }
}
