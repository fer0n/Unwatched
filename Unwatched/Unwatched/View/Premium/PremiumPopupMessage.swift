//
//  PremiumView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PremiumPopupMessage: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: Const.premiumIndicatorSF)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.contrastColor, theme.color)
                PremiumWordLogo()
            }
            .font(.title2)

            Text("unwatchedPremiumSubtitle")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("unwatchedPremiumBody")

            Button {
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    NavigationManager.shared.showPremiumOffer = true
                }
            } label: {
                Text("learnMore")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                dismiss()
            } label: {
                Text("close")
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 0, idealWidth: 300, maxWidth: 300)
        .fixedSize()
        .padding(.horizontal, 20)
        .padding(.vertical, 25)
        .apply {
            if #available(iOS 26, macOS 26, *) {
                $0
                    .glassEffect(in: RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .glassEffectTransition(.materialize )
            } else {
                $0
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 10)
                    .background(Color.insetBackgroundColor)
            }
        }
        .tint(theme.darkColor)
    }
}

struct PremiumWordLogo: View {
    var body: some View {
        HStack {
            Text(verbatim: "Unwatched")
                .fontWeight(.black)

            Text(verbatim: "Premium")
                .foregroundStyle(.secondary)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    PremiumPopupMessage(dismiss: {})
}
