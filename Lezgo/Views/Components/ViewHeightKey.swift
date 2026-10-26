//
//  ViewHeightKey.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 26/10/26.
//


import SwiftUI

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 260
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func readHeight(onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self, perform: onChange)
    }
}
