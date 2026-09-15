//
//  CapsuleLabel.swift
//  Unwatched
//

import SwiftUI

/// The single-line label of a capsule button: an icon and a value on one line.
struct CapsuleLabel<Icon: View>: View {
    var text: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 3) {
            icon
            Text(text)
        }
        .fontWidth(.condensed)
        .fontWeight(.semibold)
        .padding(10)
    }
}

struct CapsuleMenuLabel: View {
    var systemImage: String
    var menuLabel: LocalizedStringKey
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(menuLabel, systemImage: systemImage)
                .labelStyle(.regularSpacing)
                .font(.system(size: 13))
                .opacity(0.7)
            Text(text)
                .fontWidth(.condensed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

struct RegularSpacingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == RegularSpacingLabelStyle {
    static var regularSpacing: RegularSpacingLabelStyle { RegularSpacingLabelStyle() }
}
