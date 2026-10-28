//
//  TripGroup.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 26/10/26.
//

import Foundation

/// The IDs of a trip made by `TripPhones.MakeGroup()`: Agus leads, Budi and Citra are members.
struct TripGroup {
    let tripID: UUID
    let roomCode: String
    let agusID: UUID
    let budiID: UUID
    let citraID: UUID
}
