//
//  WarningPopoverContent.swift
//  Unwatched
//

import SwiftUI

struct WarningPopoverContent<Actions: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: Text
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                message
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    actions()
                }
                .padding(.top, 10)
                .myTint()
            }
        }
        // the button's bold carries over otherwise
        .fontWeight(.regular)
        .fixedSize(horizontal: false, vertical: true)
        .frame(idealWidth: 300, maxWidth: 300, alignment: .leading)
        .padding()
    }
}

#Preview {
    WarningPopoverContent(
        systemImage: "person.crop.circle.badge.exclamationmark",
        title: "youtubeLoginLost",
        message: Text("youtubeLoginLostMessage")
    ) {
        Button("dismissHint") {}
            .buttonStyle(.bordered)
        Button("youtubeLoginAgain") {}
            .buttonStyle(.borderedProminent)
    }
}
