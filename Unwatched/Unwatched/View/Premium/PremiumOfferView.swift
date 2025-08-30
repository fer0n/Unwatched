//
//  PremiumOfferView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PremiumOfferView: View {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @AppStorage(Const.hidePremium) var hidePremium: Bool = false
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
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(PremiumFeatureLarge.allCases, id: \.self) { feature in
                            HStack(alignment: .top) {
                                Image(systemName: feature.icon)
                                    .frame(maxWidth: 40, alignment: .center)
                                    .font(.largeTitle)
                                    .symbolVariant(.fill)
                                    .fontWeight(.bold)

                                VStack(alignment: .leading) {
                                    Text(feature.title)
                                        .font(.headline)
                                        .fontWeight(.bold)

                                    Text(feature.description)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 10)
                        }

                        Spacer()

                        ForEach(PremiumFeature.allCases, id: \.self) { feature in
                            HStack(alignment: .center) {
                                Image(systemName: feature.icon)
                                    .frame(maxWidth: 40, alignment: .center)
                                    .font(.title)
                                    .symbolVariant(.fill)
                                    .fontWeight(.bold)

                                Text(feature.title)
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 15)
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
                    .frame(height: 50)

                VStack {
                    Text("hidePremiumOfferDescription")
                        .foregroundStyle(.secondary)
                    Toggle(isOn: $hidePremium) {
                        Text("hidePremiumOffer")
                    }
                    .tint(theme.darkColor.mix(with: .black, by: 0.8))
                }
                .tint(theme.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(theme.darkColor.mix(with: .black, by: 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

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
    //        .frame(
    //            width: 450,
    //            height: 650
    //        )
}
