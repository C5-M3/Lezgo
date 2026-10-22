import Foundation
import SwiftData
import Testing
@testable import Lezgo

struct ItemTests {
    @Test func SavedItemKeepsItsTimestamp() throws {
        let container = try ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_000)

        context.insert(Item(timestamp: timestamp))
        try context.save()

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.timestamp == timestamp)
    }
}
