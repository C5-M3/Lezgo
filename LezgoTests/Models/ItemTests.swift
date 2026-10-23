import Foundation
import SwiftData
import Testing
@testable import Lezgo

struct ItemTests {
    @Test func SavedItemKeepsItsTimestamp() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Item.self, configurations: configuration)
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_000)

        context.insert(Item(timestamp: timestamp))
        try context.save()

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.timestamp == timestamp)
    }
}
