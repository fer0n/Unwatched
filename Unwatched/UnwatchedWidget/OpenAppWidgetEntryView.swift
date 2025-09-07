//
//  OpenAppWidgetEntryView.swift
//  Unwatched
//

import SwiftUI
import WidgetKit

struct OpenAppWidgetEntryView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image("unwatched-logo")
                .resizable()
                .scaledToFit()
                .padding(12)
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
