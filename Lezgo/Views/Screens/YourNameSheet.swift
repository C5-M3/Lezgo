//
//  YourNameSheet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import SwiftUI

/// Asks for my name the first time the app opens, so the group sees it on the map and in the Trip Room
/// (`specs/UserStories.md` → US-04). iOS no longer tells apps the iCloud account's name.
struct YourNameSheet: View {
    let viewModel: HomeViewModel
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: .yourNameField), text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.continue)
                        .focused($isNameFocused)
                        .onSubmit(Save)
                        .onChange(of: name) {
                            if name.count > ParticipantProfile.maximumNameLength {
                                name = String(name.prefix(ParticipantProfile.maximumNameLength))
                            }
                        }
                } footer: {
                    Text(.yourNameFooter)
                }
            }
            .navigationTitle(Text(.yourNameTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: Save) { Text(.yourNameContinue) }
                        .disabled(ParticipantProfile.CleanedName(name) == nil)
                }
            }
            .onAppear { isNameFocused = true }
        }
        .presentationDetents([.medium, .large])
        // The name is needed before creating or joining a trip, so the sheet cannot be swiped away.
        .interactiveDismissDisabled()
    }

    private func Save() {
        viewModel.SaveName(name)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        YourNameSheet(viewModel: HomeViewModel(mapService: MapService(), searchService: LocationSearchService()))
    }
}

#Preview("Largest text") {
    Color.clear.sheet(isPresented: .constant(true)) {
        YourNameSheet(viewModel: HomeViewModel(mapService: MapService(), searchService: LocationSearchService()))
            .dynamicTypeSize(.accessibility5)
    }
}
