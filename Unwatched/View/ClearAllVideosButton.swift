//
//  ClearAllVideosButton.swift
//  Unwatched
//

import SwiftUI

struct ClearAllVideosButton: View {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    @State private var showingClearAllAlert = false
    @State private var hapticToggle = false

    var clearAll: () -> Void

    var body: some View {
        Button {
            if requireClearConfirmation {
                showingClearAllAlert = true
            } else {
                clearAllWithHaptics()
            }
        } label: {
            HStack {
                Spacer()
                Image(systemName: Const.clearSF)
                    .resizable()
                    .frame(width: 30, height: 30)
                Spacer()
            }.padding()
        }
        .actionSheet(isPresented: $showingClearAllAlert) {
            ActionSheet(title: Text("confirmClearAll"),
                        message: Text("areYouSureClearAll"),
                        buttons: [
                            .destructive(Text("clearAll")) { clearAllWithHaptics() },
                            .cancel()
                        ])
        }
        .foregroundStyle(Color.neutralAccentColor)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    func clearAllWithHaptics() {
        hapticToggle.toggle()
        clearAll()
    }
}

#Preview {
    ClearAllVideosButton(clearAll: {})
}
