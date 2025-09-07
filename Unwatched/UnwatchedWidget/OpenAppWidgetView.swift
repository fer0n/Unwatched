//
//  OpenAppWidgetView.swift
//  Unwatched
//

import SwiftUI
import WidgetKit

struct OpenAppWidgetView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image("unwatched-logo")
                .resizable()
                .scaledToFit()
                .padding(12)
                .padding(.bottom, 2)
        }
        .widgetAccentable()
        .containerBackground(.regularMaterial, for: .widget)
    }
}

#Preview(as: .accessoryCircular, widget: {
    OpenAppWidget()
}, timeline: {
    SimpleEntry(date: Date())
})
