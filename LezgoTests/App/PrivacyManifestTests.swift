//
//  PrivacyManifestTests.swift
//  LezgoTests
//
//  Created by Nathan Sudiara on 17/11/26.
//

import Foundation
import Testing

/// App Store Connect rejects a build that uses a required-reason API without a privacy manifest that declares it
/// (ITMS-91053). The tests read the manifest from the built app, so they also catch a file left out of the bundle.
struct PrivacyManifestTests {
    private static let userDefaultsCategory = "NSPrivacyAccessedAPICategoryUserDefaults"

    /// The reason for reading and writing data that only this app uses (Apple's code `CA92.1`).
    private static let ownDataReason = "CA92.1"

    private func Manifest() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test func ManifestSaysTheAppDoesNotTrack() throws {
        let manifest = try Manifest()

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test func ManifestDeclaresUserDefaultsForTheAppsOwnData() throws {
        let manifest = try Manifest()
        let accessedAPIs = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try #require(accessedAPIs.first {
            $0["NSPrivacyAccessedAPIType"] as? String == Self.userDefaultsCategory
        })

        #expect(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == [Self.ownDataReason])
    }

    @Test func ManifestDeclaresTheDataSharedWithTheGroup() throws {
        let manifest = try Manifest()
        let collected = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String })

        #expect(types == [
            "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypePreciseLocation",
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeOtherUserContent"
        ])
        #expect(collected.allSatisfy { $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false })
    }
}
