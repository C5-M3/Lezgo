//
//  PreciseLocationNotice.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import SwiftUI

/// Shown on the Trip Room and the trip map while Precise Location is off. Lezgo then only knows the phone's position
/// to a few kilometres, so this car is not shared and cannot be ready at the start point. The button opens Lezgo in
/// Settings, where Precise Location is turned on.
struct PreciseLocationNotice: View {
    @Environment(\.openURL) private var openURL

    /// Lezgo's own page in the Settings app (the value of `UIApplication.openSettingsURLString`).
    private static let settingsURL = URL(string: "app-settings:")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(.preciseLocationOff)
                        .font(.headline)
                    Text(.preciseLocationOffDetail)
                        .font(.subheadline)
                }
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "location.slash.fill")
                    .accessibilityHidden(true)
            }
            if let settingsURL = Self.settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Text(.preciseLocationOpenSettings)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview("Precise Location off") {
    PreciseLocationNotice()
        .padding()
}

#Preview("Largest text") {
    PreciseLocationNotice()
        .padding()
        .dynamicTypeSize(.accessibility5)
}
