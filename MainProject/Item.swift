//
//  Item.swift
//  MainProject
//
//  Created by Nathan Sudiara on 20/10/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
