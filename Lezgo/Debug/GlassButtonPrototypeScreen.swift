//
//  GlassButtonPrototypeScreen.swift
//  Lezgo
//

#if DEBUG
import MapKit
import SwiftUI

/// Every button role, surface level, text colour and radius of the shared look (ADR 0032, ADR 0033) on one
/// screen, so the team can judge it on a map and on each surface.
///
/// Open it with `-DebugScreen glassButtons`.
struct GlassButtonPrototypeScreen: View {
    enum Backdrop: String, CaseIterable, Identifiable {
        case map = "Map"
        case page = "Page"
        case level1 = "Level 1"
        case level2 = "Level 2"
        case yellow = "Yellow"

        var id: String { rawValue }
    }

    @State private var backdrop = Backdrop.map

    var body: some View {
        ZStack {
            GlassButtonPrototypeBackdrop(backdrop: backdrop)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Picker("Backdrop", selection: $backdrop) {
                        ForEach(Backdrop.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    RoleSection()
                    RoundButtonSection()
                    ImageButtonSection()
                    SurfaceSwatchSection()
                    SheetSection()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// What sits behind the glass: glass is drawn from whatever is under it.
private struct GlassButtonPrototypeBackdrop: View {
    let backdrop: GlassButtonPrototypeScreen.Backdrop

    var body: some View {
        switch backdrop {
        case .map:
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -7.2858, longitude: 112.6318),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )))
            .allowsHitTesting(false)
            .ignoresSafeArea()
        case .page:
            Color(LezgoSurface.page.color).ignoresSafeArea()
        case .level1:
            Color(LezgoSurface.level1.color).ignoresSafeArea()
        case .level2:
            Color(LezgoSurface.level2.color).ignoresSafeArea()
        case .yellow:
            Color(.brandYellow).ignoresSafeArea()
        }
    }
}

#Preview {
    GlassButtonPrototypeScreen()
}
#endif
