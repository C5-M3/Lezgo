//
//  EntitlementsTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 09/11/26.
//

import Foundation
import Testing

/// `Lezgo.entitlements` is for accounts without the CarPlay entitlement; `LezgoCarPlay.entitlements` is the same
/// plus CarPlay (ADR 0023). A capability added to one file only would be missing from some builds.
struct EntitlementsTests {
    private static let carPlayKey = "com.apple.developer.carplay-maps"

    /// The app folder, found from this file: the tests run in the simulator on the Mac that has the sources.
    private static let appFolder = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Lezgo")

    private func Entitlements(_ fileName: String) throws -> [String: Any] {
        let data = try Data(contentsOf: Self.appFolder.appending(path: fileName))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test func CarPlayFileAddsOnlyCarPlay() throws {
        let carPlayPath = Self.appFolder.appending(path: "LezgoCarPlay.entitlements").path()
        guard FileManager.default.fileExists(atPath: carPlayPath) else {
            return
        }
        var carPlay = try Entitlements("LezgoCarPlay.entitlements")
        let withoutCarPlay = try Entitlements("Lezgo.entitlements")

        #expect(carPlay.removeValue(forKey: Self.carPlayKey) as? Bool == true)
        #expect(NSDictionary(dictionary: carPlay).isEqual(to: withoutCarPlay))
    }

    /// Universal links open the app only for hosts in Associated Domains (ADR 0036). The old Netlify host stays
    /// so invites shared from Lezgo 1.0 keep opening the app.
    @Test func AppOpensInviteLinksOnTheNewAndTheOldHost() throws {
        let entitlements = try Entitlements("Lezgo.entitlements")
        let domains = try #require(entitlements["com.apple.developer.associated-domains"] as? [String])

        #expect(domains.contains("applinks:joinlezgo.app"))
        #expect(domains.contains("applinks:lezgo-trip.netlify.app"))
    }
}
