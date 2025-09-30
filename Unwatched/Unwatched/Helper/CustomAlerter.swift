//
//  CustomAlerter.swift
//  Unwatched
//

import SwiftUI

struct CustomAlerter: ViewModifier {
    @State var alerter = Alerter()

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            .environment(alerter)
            .overlay {
                PremiumPopupMessage(dismiss: {
                    alerter.showPremium = false
                })
                .frame(minWidth: 0, idealWidth: 300, maxWidth: 300)
                .fixedSize()
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
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
                .opacity(alerter.showPremium ? 1 : 0)
                .scaleEffect(alerter.showPremium ? 1 : 0.9)
                .animation(.default, value: alerter.showPremium)
            }
    }
}

struct PreviewAlerter: View {
    @Environment(Alerter.self) var alerter

    var body: some View {
        Button {
            SheetPositionReader.shared.setDetentMinimumSheet()
            Task {
                alerter.showPremium = true
            }
        } label: {
            Text(verbatim: "Show Alert")
        }
    }
}

#Preview {
    PreviewAlerter()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(CustomAlerter())
        .environment(Alerter())
}
