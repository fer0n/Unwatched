//
//  BrowserAlternatives.swift
//  Unwatched
//

import SwiftUI

struct BrowserAlternatives: View {
    private struct Alternative: Identifiable {
        let name: String
        let description: LocalizedStringKey
        let appStoreId: String

        var id: String { appStoreId }
    }

    private let alternatives = [
        Alternative(name: "SwizzTube", description: "settingsSplashSwizzTubeDescription", appStoreId: "6466721604"),
        Alternative(name: "BlockIt", description: "settingsSplashBlockItDescription", appStoreId: "1492879257"),
        Alternative(name: "AdBlock Pro", description: "settingsSplashAdBlockProDescription", appStoreId: "1018301773")
    ]

    var body: some View {
        DisclosureGroup("settingsSplashBrowserAlternatives") {
            VStack(alignment: .leading, spacing: 8) {
                Text("settingsSplashBrowserAlternativesDescription")
                    .foregroundStyle(Color.secondary)

                ForEach(alternatives) { alternative in
                    if let url = URL(string: "https://apps.apple.com/app/id\(alternative.appStoreId)") {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(verbatim: alternative.name)
                                    .fontWeight(.semibold)
                                Text(alternative.description)
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            .padding(.top, 8)
        }
        .disclosureGroupStyle(TintedChevronDisclosureStyle())
    }
}

private struct TintedChevronDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
