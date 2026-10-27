//
//  EditProfileSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct EditProfileSheetView: View {
    let viewModel: TripRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var myParticipant: Participant? {
        viewModel.participants.first(where: { $0.id == viewModel.myParticipantID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Details") {
                    TextField("Name", text: $name).focused($isNameFocused)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        Task {
                            try? await viewModel.UpdateProfile(displayName: trimmedName, carDescription: description)
                        }
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if let me = myParticipant {
                    name = me.displayName
                    description = me.carDescription
                }
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}
