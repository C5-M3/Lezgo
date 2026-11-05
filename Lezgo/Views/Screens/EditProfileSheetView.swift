//
//  EditProfileSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

/// Edits one participant's name and car: my own, or anyone's when I lead the trip.
struct EditProfileSheetView: View {
    let viewModel: TripRoomViewModel
    let participant: Participant
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Details") {
                    TextField("Name", text: $name)
                        .focused($isNameFocused)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 30 {
                                name = String(newValue.prefix(30))
                            }
                        }
                    TextField("Car description", text: $description)
                        .onChange(of: description) { _, newValue in
                            if newValue.count > 40 {
                                description = String(newValue.prefix(40))
                            }
                        }
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
                            let didSave = await viewModel.SaveProfile(
                                displayName: trimmedName,
                                carDescription: trimmedDescription,
                                of: participant.id
                            )
                            if didSave { dismiss() }
                        }
                    }
                    .disabled(trimmedName.isEmpty || viewModel.isSavingProfile)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.profileErrorMessage != nil },
                    set: { if !$0 { viewModel.profileErrorMessage = nil } }
                )
            ) {
                Button("OK") { viewModel.profileErrorMessage = nil }
            } message: {
                if let message = viewModel.profileErrorMessage {
                    Text(message)
                }
            }
            .onAppear {
                name = participant.displayName
                description = participant.carDescription
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview("Leader edits a member") {
    let state = SampleTrip.State(status: .lobby)
    Color.clear.sheet(isPresented: .constant(true)) {
        if let member = state.participants.first(where: { $0.id == SampleTrip.budiID }) {
            EditProfileSheetView(
                viewModel: TripRoomViewModel(
                    tripService: SampleTrip.Service(status: .lobby, me: SampleTrip.agusID),
                    tripID: SampleTrip.tripID,
                    myParticipantID: SampleTrip.agusID,
                    initialState: state
                ),
                participant: member
            )
        }
    }
}
#endif
