//
//  LezgoWidgetsBundle.swift
//  LezgoWidgets
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI
import WidgetKit

/// Lezgo's widget extension: only the trip's Live Activity (ADR 0027).
@main
struct LezgoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivityWidget()
    }
}
