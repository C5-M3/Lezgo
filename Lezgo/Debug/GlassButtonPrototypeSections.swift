//
//  GlassButtonPrototypeSections.swift
//  Lezgo
//

#if DEBUG
import SwiftUI

/// A titled group of rows on the prototype screen.
private struct PrototypeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3)
            content
        }
    }
}

/// The four button roles, enabled and disabled.
struct RoleSection: View {
    var body: some View {
        PrototypeSection(title: "1. Button roles") {
            Button("Start Trip") {}.lezgoGlassButton(.main)
            Button("New Trip") {}.lezgoGlassButton(.second)
            Button("End Trip") {}.lezgoGlassButton(.destructive)
            HStack(spacing: 12) {
                Button("Enter") {}.lezgoGlassButton(.main)
                Button("New Trip") {}.lezgoGlassButton(.second)
            }
            .disabled(true)
        }
    }
}

/// Back, camera, sound: alone at 44 points, and as a group of map controls at 61 points.
struct RoundButtonSection: View {
    private static let icons = [
        "location.north.fill",
        "speaker.wave.2.fill",
        "point.topleft.down.to.point.bottomright.curvepath.fill"
    ]

    var body: some View {
        PrototypeSection(title: "2. Round buttons") {
            HStack(spacing: 16) {
                Button("Back", systemImage: "chevron.left") {}
                    .labelStyle(.iconOnly)
                    .font(.callout.weight(.bold))
                    .lezgoGlassButton(.round)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Button { } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 61, height: 61)
                            }
                            .accessibilityLabel("Map control")
                        }
                    }
                    .lezgoGlassButton(.round)
                }
            }
        }
    }
}

/// A button that holds a picture, which takes `lezgoGlass(role:in:)`.
struct ImageButtonSection: View {
    var body: some View {
        PrototypeSection(title: "3. Button with a picture") {
            Button { } label: {
                HStack {
                    AvatarImage(avatar: .yellow, isSelected: false).frame(height: 36)
                    Text("Agus").font(.headline)
                }
                .foregroundStyle(Color(.tripCardText))
                .padding(.horizontal, 20)
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .lezgoGlass(role: .second, in: .capsule)
        }
    }
}

/// The three surface levels, the separator, both text colours and the three radii.
struct SurfaceSwatchSection: View {
    var body: some View {
        PrototypeSection(title: "4. Surfaces, text and radii") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Level 1 card, radius 30").font(.headline).foregroundStyle(Color(.tripCardText))
                Text("Secondary text").font(.subheadline).foregroundStyle(Color(.tripCardSubtext))
                Divider().overlay(Color(.surfaceSeparator))
                Text("Level 2 field, radius 20")
                    .foregroundStyle(Color(.tripCardText))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lezgoSurface(.level2, radius: LezgoRadius.field)
                HStack(spacing: 8) {
                    ForEach(["4", "2", "7"], id: \.self) { digit in
                        Text(digit)
                            .font(.title2.bold())
                            .foregroundStyle(Color(.tripCardText))
                            .frame(width: 48, height: 56)
                            .lezgoSurface(.level2, radius: LezgoRadius.small)
                    }
                }
                Button("Cancel") {}.lezgoGlassButton(.second)
                Button("End Trip") {}.lezgoGlassButton(.destructive)
            }
            .padding(20)
            .lezgoSurface(.level1, radius: LezgoRadius.card)
            .padding(12)
            .lezgoSurface(.page, radius: LezgoRadius.card)
        }
    }
}

/// Opens a sheet with the one sheet look.
struct SheetSection: View {
    @State private var isSheetShown = false

    var body: some View {
        PrototypeSection(title: "5. Sheet") {
            Button("Open sheet") { isSheetShown = true }.lezgoGlassButton(.second)
        }
        .sheet(isPresented: $isSheetShown) {
            VStack(spacing: 16) {
                Text("Enter room code").font(.title3.bold()).foregroundStyle(Color(.tripCardText))
                Text("Ask the leader for the 6-digit code")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tripCardSubtext))
                Text("427 913")
                    .font(.title.bold())
                    .foregroundStyle(Color(.tripCardText))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .lezgoSurface(.level1, radius: LezgoRadius.field)
                Button("Enter") { isSheetShown = false }.lezgoGlassButton(.main)
            }
            .padding(24)
            .presentationDetents([.height(320)])
            .lezgoSheet()
        }
    }
}
#endif
