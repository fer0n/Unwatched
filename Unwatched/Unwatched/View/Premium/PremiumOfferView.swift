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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(systemName: Const.premiumIndicatorSF)
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.color, theme.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .padding(.bottom)

                VStack(alignment: .leading) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle(isOn: $hidePremium) {
                            Text("hidePremiumOffer")
                        }
                        .signalToggle("Premium.Hide", isOn: hidePremium)
                        .tint(toggleTint)
                    }
                    .tint(theme.color)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .padding(.horizontal)
            }
            .softSafeAreaBar(edge: .bottom) {
                Button {
                    Signal.signalBool("Premium.Subscribe", value: !premium)
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
                .padding(25)
            }
            #if !os(visionOS)
            .scrollEdgeEffectStyle(.soft, for: .top)
            #endif
            .sensoryFeedback(Const.sensoryFeedback, trigger: premium)
            .tint(theme.darkContrastColor)
            .foregroundStyle(theme.darkContrastColor)
            #if os(iOS)
            .background(backgroundColor.gradient)
            #else
            .background(backgroundColor)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }

            ZStack {}
                .myNavigationTitle("unwatchedPremium")
                .foregroundStyle(theme.darkContrastColor)
        }
    }

    // black/white's darkColor is white in light mode: keep it near white instead of a muddy gray
    var backgroundColor: Color {
        theme.darkColor.mix(with: .black, by: theme == .blackWhite ? 0.03 : 0.4)
    }

    var cardColor: Color {
        theme.darkColor.mix(with: .black, by: theme == .blackWhite ? 0.08 : 0.45)
    }

    var toggleTint: Color {
        // black/white's darkColor is black in dark mode, so darkening it vanishes into the card
        theme == .blackWhite
            ? theme.darkContrastColor.opacity(0.5)
            : theme.darkColor.mix(with: .black, by: 0.8)
    }
}

#Preview {
    PremiumOfferView()
        .previewEnvironments()
}
