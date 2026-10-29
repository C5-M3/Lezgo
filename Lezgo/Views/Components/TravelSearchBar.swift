//
//  TravelSearchBar.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import MapKit
import SwiftUI

/// Komponen bilah pencarian mengambang bergaya Apple Maps.
/// - iOS 18 ke atas: Menggunakan sistem Liquid Glass (HIG) dengan `glassEffect` dan `buttonStyle(.glass)`.
/// - Di bawah iOS 18: Menggunakan Material standar Apple HIG (`.ultraThinMaterial` / `.regularMaterial`).
struct TravelSearchBar: View {
    var placeholder: String = "Where do you want to travel ?"
    var onTap: (() -> Void)?

    var body: some View {
        if #available(iOS 18.0, *) {
            liquidGlassSearchBar
        } else {
            legacyMaterialSearchBar
        }
    }

    // MARK: - iOS 18+ Liquid Glass Implementation

    @available(iOS 18.0, *)
    private var liquidGlassSearchBar: some View {
        HStack(spacing: 8) {
            // Kolom teks pencarian dengan Liquid Glass
            HStack(spacing: 8) {
                searchPromptView
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .glassEffect(.regular.interactive(), in: Capsule())

            // Tombol ikon pencarian dengan tombol kaca HIG
            Button {
                onTap?()
            } label: {
                searchIconView
                    .frame(width: 30, height: 40)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Cari lokasi")
        }
        .padding(5)
        .background {
            Capsule()
                .fill(Color(uiColor: .systemGray4).opacity(0.35))
        }
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .contentShape(Capsule())
        .onTapGesture {
            onTap?()
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Pre-iOS 18 Standard Material Implementation

    private var legacyMaterialSearchBar: some View {
        HStack(spacing: 8) {
            // Kolom teks pencarian dengan Material standar
            HStack(spacing: 8) {
                searchPromptView
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(.ultraThinMaterial, in: Capsule())

            // Tombol ikon pencarian dengan material bundar
            Button {
                onTap?()
            } label: {
                searchIconView
                    .foregroundStyle(Color(uiColor: .label).opacity(0.85))
                    .frame(width: 30, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cari lokasi")
        }
        .padding(5)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .fill(Color(uiColor: .systemGray4).opacity(0.55))
                )
        }
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        .contentShape(Capsule())
        .onTapGesture {
            onTap?()
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Shared Views

    private var searchPromptView: some View {
        HStack(spacing: 8) {
            Text(placeholder)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(uiColor: .placeholderText).opacity(0.85))
                .lineLimit(1)
            Spacer()
        }
    }

    private var searchIconView: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 20, weight: .medium))
            .accessibilityHidden(true)
    }
}

/// Tombol aksi mengambang berbentuk lingkaran untuk kontrol peta (seperti tombol pintu/keluar).
/// Menggunakan Liquid Glass pada iOS 18+ dan Material standar pada iOS di bawahnya.
struct MapDoorButton: View {
    var action: () -> Void = {}

    var body: some View {
        if #available(iOS 18.0, *) {
            Button(action: action) {
                Image(systemName: "door.left.hand.closed")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 30, height: 40)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Buka Menu Room Trip")
        } else {
            Button(action: action) {
                Image(systemName: "door.left.hand.closed")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label).opacity(0.85))
                    .frame(width: 30, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buka Menu Room Trip")
        }
    }
}

/// Komponen gabungan yang menyertakan tombol pintu melayang dan bilah pencarian mengambang.
struct TravelMapControlsView: View {
    var placeholder: String = "Where do you want to travel ?"
    var onDoorTapped: (() -> Void)?
    var onTap: (() -> Void)?

    init(
        placeholder: String = "Where do you want to travel ?",
        onDoorTapped: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self.onDoorTapped = onDoorTapped
        self.onTap = onTap
    }

    init(
        placeholder: String = "Where do you want to travel ?",
        onDoorTapped: (() -> Void)? = nil,
        onTapSearch: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self.onDoorTapped = onDoorTapped
        self.onTap = onTapSearch
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            GlassEffectContainer(spacing: 14) {
                controlsStack
            }
        } else {
            controlsStack
        }
    }

    private var controlsStack: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Tombol pintu melayang di kanan atas
            MapDoorButton {
                onDoorTapped?()
            }

            // Bilah pencarian di bagian bawah
            TravelSearchBar(
                placeholder: placeholder,
                onTap: onTap
            )
        }
    }
}

// MARK: - Keyboard Helper

extension View {
    /// Menutup keyboard sistem (resign first responder).
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - Previews

#Preview("Adaptive Travel Controls") {
    ZStack(alignment: .bottom) {
        Map()
            .ignoresSafeArea()

        TravelMapControlsView(onTap: {})
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
    }
}
