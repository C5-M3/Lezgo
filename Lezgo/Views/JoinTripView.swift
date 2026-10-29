//
//  JoinTripView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import SwiftUI

/// Pop up modal Apple HIG component untuk memasukkan kode ruangan (room code) perjalanan.
/// Komponen ini terpisah dan dirancang sesuai pedoman Apple Human Interface Guidelines (HIG).
@MainActor
struct JoinTripView: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @State private var viewModel: JoinTripViewModel
    @State private var enteredCode: String = ""
    @FocusState private var isFieldFocused: Bool

    var onBack: (() -> Void)?
    var onEnter: ((String) -> Void)?

    // MARK: - Initializer

    init(
        isPresented: Binding<Bool>,
        viewModel: JoinTripViewModel? = nil,
        onBack: (() -> Void)? = nil,
        onEnter: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        let vm = viewModel ?? JoinTripViewModel()
        self._viewModel = State(initialValue: vm)
        self._enteredCode = State(initialValue: vm.roomCode)
        self.onBack = onBack
        self.onEnter = onEnter
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Latar belakang peredup (dimmed backdrop) yang menyerap seluruh interaksi sentuhan di luar modal
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Menahan interaksi agar fokus tetap pada modal dan tidak tembus ke peta di belakangnya
                }
                .accessibilityAddTraits(.isButton)

            VStack {
                Spacer()

                modalCard
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 360)
                    .onTapGesture {
                        // Menahan ketukan di dalam kartu agar tidak menutup modal
                    }
                    .accessibilityAddTraits(.isButton)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .defaultFocus($isFieldFocused, true)
        .task {
            // Memunculkan keyboard secara otomatis tanpa harus mengetuk field kode
            try? await Task.sleep(for: .milliseconds(100))
            isFieldFocused = true
        }
        .onChange(of: viewModel.roomCode) { _, newValue in
            if enteredCode != newValue {
                enteredCode = newValue
            }
        }
    }

    // MARK: - Modal Card

    private var modalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header: Judul & Deskripsi
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter room code")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text("Enter the 6 digit room code created by leader")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Kolom Input Kode (Dibatasi maksimal 6 digit angka)
            HStack {
                TextField(
                    text: $enteredCode,
                    prompt: Text("6 digit code")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .placeholderText).opacity(0.85))
                ) {
                    EmptyView()
                }
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primary)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    submitRoomCode()
                }
                .onChange(of: enteredCode) { _, newValue in
                    let digitsOnly = newValue.filter { $0.isNumber }
                    let limited = String(digitsOnly.prefix(6))
                    if enteredCode != limited {
                        enteredCode = limited
                    }
                    if viewModel.roomCode != enteredCode {
                        viewModel.roomCode = enteredCode
                    }
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .systemGray5).opacity(0.85))
            )

            // Tombol Aksi (Back & Enter)
            HStack(spacing: 12) {
                // Tombol Back
                Button {
                    dismissModal()
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(Color(uiColor: .systemGray5))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kembali")

                // Tombol Enter
                Button {
                    submitRoomCode()
                } label: {
                    Text("Enter")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.isValidCode
                                    ? Color(red: 0.0, green: 0.48, blue: 1.0)
                                    : Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.5)
                                )
                        )
                }
                .disabled(!viewModel.isValidCode)
                .buttonStyle(.plain)
                .accessibilityLabel("Masuk ke ruangan")
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
        }
    }

    // MARK: - Actions

    private func dismissModal() {
        isFieldFocused = false
        hideKeyboard()
        onBack?()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPresented = false
        }
    }

    private func submitRoomCode() {
        guard viewModel.isValidCode else { return }
        isFieldFocused = false
        hideKeyboard()
        let code = viewModel.roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        onEnter?(code)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPresented = false
        }
    }
}

// MARK: - View Extension

extension View {
    /// Menampilkan modal Pop Up Join Trip (Apple HIG) secara modular.
    @MainActor
    func joinTripModal(
        isPresented: Binding<Bool>,
        onBack: (() -> Void)? = nil,
        onEnter: ((String) -> Void)? = nil
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                JoinTripView(
                    isPresented: isPresented,
                    onBack: onBack,
                    onEnter: onEnter
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                    removal: .identity
                ))
                .zIndex(999)
            }
        }
    }
}

// MARK: - Previews

#Preview("Join Trip Modal") {
    ZStack {
        Color.gray.opacity(0.2)

        JoinTripView(isPresented: .constant(true))
    }
}
