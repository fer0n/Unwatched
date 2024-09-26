//
//  ClearAllVideosButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ClearAllVideosButton: View {

    @State private var triggerAction = false
    var clearAll: () -> Void

    var body: some View {
        Button {
            triggerAction = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: Const.clearSF)
                    .resizable()
                    .frame(width: 30, height: 30)
                Spacer()
            }.padding()
        }
        .clearConfirmation(clearAll: clearAll, triggerAction: $triggerAction)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.backgroundColor)
        .accessibilityLabel("clearAllVideos")
    }
}

struct ClearConfirmationModifier: ViewModifier {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    @State private var showingClearAllAlert = false
    @State private var hapticToggle = false
    @Binding var triggerAction: Bool

    var clearAll: () -> Void
    var clearText: LocalizedStringKey = "clearAll"

    func body(content: Content) -> some View {
        content
            .confirmationDialog("confirmClearAll",
                                isPresented: $showingClearAllAlert) {
                Button(role: .destructive, action: {
                    clearAllWithHaptics()
                }, label: {
                    Text(clearText)
                })
                Button("cancel", role: .cancel, action: {
                    showingClearAllAlert = false
                })
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            .onChange(of: triggerAction) {
                if triggerAction {
                    onTriggerAction()
                }
            }
    }

    func onTriggerAction() {
        if requireClearConfirmation {
            showingClearAllAlert = true
        } else {
            clearAllWithHaptics()
        }
        triggerAction = false
    }

    func clearAllWithHaptics() {
        hapticToggle.toggle()
        clearAll()
    }
}

extension View {
    func clearConfirmation(clearAll: @escaping () -> Void, triggerAction: Binding<Bool>) -> some View {
        self.modifier(ClearConfirmationModifier(triggerAction: triggerAction,
                                                clearAll: clearAll))
    }
}

#Preview {
    ClearAllVideosButton(clearAll: {})
}
