//
//  PremiumOfferView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PremiumOfferView: View {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "Unwatched")
                        .fontWeight(.black)
                    HStack {
                        Image(systemName: Const.premiumIndicatorSF)
                            .foregroundStyle(.secondary)
                        Text(verbatim: "Premium")
                            .foregroundStyle(.secondary)
                            .fontWeight(.bold)
                    }
                }
                .font(.largeTitle)
                .padding(.bottom, 20)
                .padding(.top, 60)

                Text("premiumOfferSubtitle")
                    .font(.headline)

                Spacer()
                    .frame(height: 50)

                MySection {
                    VStack(alignment: .leading, spacing: 25) {
                        ForEach(PremiumFeature.allCases, id: \.self) { feature in
                            HStack(alignment: .top) {
                                Image(systemName: feature.icon)
                                    .frame(maxWidth: 40, alignment: .center)
                                    .font(.largeTitle)
                                    .symbolVariant(.fill)

                                VStack(alignment: .leading) {
                                    Text(feature.title)
                                        .font(.headline)
                                        .fontWeight(.bold)

                                    Text(feature.description)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Spacer()
                    .frame(height: 100)

                Text("premiumOfferHeader")
                    .padding(.bottom, 5)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("premiumOfferDescription")
                    .foregroundStyle(.secondary)

                Spacer()
                    .frame(height: 150)
            }
            .padding(.horizontal)
        }
        .overlay {
            Button {
                premium.toggle()
            } label: {
                Text(premium ? "cancelFreeTrial" : "tryForFree")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .fontWeight(.bold)
                    .foregroundStyle(backgroundColor)
            }
            #if os(iOS)
            .buttonStyle(.borderedProminent)
            #else
            .buttonStyle(.plain)
            .background(.white, in: Capsule())
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(5)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: premium)
        .tint(theme.darkContrastColor)
        .foregroundStyle(theme.contrastColor)
        #if os(iOS)
        .background(backgroundColor.gradient)
        #else
        .background(backgroundColor)
        #endif
    }

    var backgroundColor: Color {
        theme.darkColor.mix(with: .black, by: 0.4)
    }
}

#Preview {
    PremiumOfferView()
        .frame(
            width: 450,
            height: 650
        )
}
