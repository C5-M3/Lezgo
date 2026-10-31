//
//  HomeView+Prompts.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import SwiftUI

extension HomeView {
    /// What Home asks or tells on top of everything: my name the first time the app opens, and why a saved trip
    /// could not be opened. Its own file, so `HomeView.swift` stays under SwiftLint's 400-line limit.
    struct Prompts: ViewModifier {
        @Bindable var viewModel: HomeViewModel

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $viewModel.isAskingForName) {
                    YourNameSheet(viewModel: viewModel)
                }
                .alert(
                    Text(verbatim: viewModel.draftTripErrorMessage ?? ""),
                    isPresented: Binding(
                        get: { viewModel.draftTripErrorMessage != nil },
                        set: { if $0 == false { viewModel.DismissDraftTripError() } }
                    )
                ) {
                    Button("OK", action: viewModel.DismissDraftTripError)
                }
        }
    }
}
