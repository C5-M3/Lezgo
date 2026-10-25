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
    @Binding var text: String
    var placeholder: String = "Where do you want to travel ?"
    var isSearching: Bool = false
    var isFocused: FocusState<Bool>.Binding?
    var onSearch: (() -> Void)?
    var onSubmit: (() -> Void)?

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
            // Kolom input pencarian dengan Liquid Glass
            HStack(spacing: 8) {
                textFieldView
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .glassEffect(.regular.interactive(), in: Capsule())

            // Tombol ikon pencarian dengan tombol kaca HIG
            Button {
                isFocused?.wrappedValue = false
                hideKeyboard()
                onSearch?()
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
    }

    // MARK: - Pre-iOS 18 Standard Material Implementation

    private var legacyMaterialSearchBar: some View {
        HStack(spacing: 8) {
            // Kolom input pencarian dengan Material standar
            HStack(spacing: 8) {
                textFieldView
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(.ultraThinMaterial, in: Capsule())

            // Tombol ikon pencarian dengan material bundar
            Button {
                isFocused?.wrappedValue = false
                hideKeyboard()
                onSearch?()
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
    }

    // MARK: - Shared Views

    private var textFieldView: some View {
        HStack(spacing: 8) {
            Group {
                if let isFocused {
                    textFieldInput
                        .focused(isFocused)
                } else {
                    textFieldInput
                }
            }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hapus teks pencarian")
            }
        }
    }

    private var textFieldInput: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(uiColor: .placeholderText).opacity(0.85))
        )
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.primary)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.search)
        .onSubmit {
            isFocused?.wrappedValue = false
            hideKeyboard()
            onSubmit?()
        }
    }

    @ViewBuilder
    private var searchIconView: some View {
        if isSearching {
            ProgressView()
                .scaleEffect(0.85)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .accessibilityHidden(true)
        }
    }
}

/// Tampilan daftar saran/rekomendasi pencarian tempat dari Apple MapKit (`MKLocalSearchCompletion`).
struct LocationSuggestionsListView: View {
    var suggestions: [MKLocalSearchCompletion]
    var onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        if #available(iOS 18.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(suggestions.prefix(6).enumerated()), id: \.offset) { index, item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)

                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < min(suggestions.count, 6) - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxHeight: 220)
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
            .accessibilityLabel("Kembali ke Lokasi Pengguna atau Reset")
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
            .accessibilityLabel("Kembali ke Lokasi Pengguna atau Reset")
        }
    }
}

/// Komponen gabungan yang menyertakan tombol pintu melayang, daftar saran pencarian (autocomplete),
/// dan bilah pencarian mengambang.
struct TravelMapControlsView: View {
    @Binding var searchText: String
    var placeholder: String = "Where do you want to travel ?"
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false
    var isFocused: FocusState<Bool>.Binding?
    var onDoorTapped: (() -> Void)?
    var onSearch: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onSelectSuggestion: ((MKLocalSearchCompletion) -> Void)?

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
                isFocused?.wrappedValue = false
                hideKeyboard()
                onDoorTapped?()
            }

            // Daftar saran autocomplete yang muncul ketika ada hasil saran dan kolom pencarian aktif
            if (isFocused?.wrappedValue ?? true) && !suggestions.isEmpty {
                LocationSuggestionsListView(suggestions: suggestions) { suggestion in
                    isFocused?.wrappedValue = false
                    hideKeyboard()
                    onSelectSuggestion?(suggestion)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }

            // Bilah pencarian di bagian bawah
            TravelSearchBar(
                text: $searchText,
                placeholder: placeholder,
                isSearching: isSearching,
                isFocused: isFocused,
                onSearch: onSearch,
                onSubmit: onSubmit
            )
        }
        .animation(.easeInOut(duration: 0.25), value: suggestions.isEmpty)
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

        TravelMapControlsView(searchText: .constant(""))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
    }
}
