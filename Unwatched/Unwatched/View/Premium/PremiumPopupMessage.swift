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
            Image(systemName: Const.premiumIndicatorSF)
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(theme.color, theme.color.opacity(0.2))
                .frame(width: 45, height: 45)

            PremiumWordLogo()
                .font(.title)

            Text("unwatchedPremiumBody")
                .font(.headline)
                .padding(.bottom)

            Button {
                dismiss()
                Task { @MainActor in
                    NavigationManager.shared.showMenu = true
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
                    .glassEffect(in: clipShape)
                    .glassEffectTransition(.materialize )
            } else {
                $0
                    .background(Color.insetBackgroundColor)
                    .clipShape(clipShape)
                    .shadow(radius: 10)
            }
        }
        .tint(theme.darkColor)
    }

    var clipShape: some Shape {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
    }
}

struct PremiumWordLogo: View {
    var body: some View {
        HStack(spacing: 5) {
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
