//
//  QueueSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct QueueSettingsView: View {
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection {
                    Toggle(isOn: $showClearQueueButton) {
                        Text("showClearQueueButton")
                    }
                }

                #if os(iOS)
                MySection(footer: "enableQueueContextMenuFooter") {
                    Toggle(isOn: $enableQueueContextMenu) {
                        Text("enableQueueContextMenu")
                    }
                }
                #endif
            }
            .myNavigationTitle("queue")
        }
    }
}

#Preview {
    QueueSettingsView()
}
