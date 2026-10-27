//
//  SyncCheckLogEntry.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

#if DEBUG
import Foundation

/// One line in the Sync Check log: what changed in the trip, and when this phone saw it.
struct SyncCheckLogEntry: Identifiable, Hashable {
    let id = UUID()
    let seenAt: Date
    let message: String
}
#endif
