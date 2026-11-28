//
//  InboxSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InboxSettingsView: View {
    @AppStorage(Const.inboxOldestFirst) var inboxOldestFirst: Bool = false
    @AppStorage(Const.inboxAppearance) var inboxAppearance: InboxAppearance = .cards
    @CloudStorage(Const.autoDeleteInboxVideosLimit) var autoDeleteInboxVideosLimit: Int = 100

    static let inboxLimitOptions = [0, 20, 50, 100, 500]

    static func inboxLimitLabel(_ limit: Int) -> LocalizedStringKey {
        limit == 0 ? "unlimited" : LocalizedStringKey("\(limit)")
    }

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection {
                    Picker("inboxAppearance", selection: $inboxAppearance) {
                        ForEach(InboxAppearance.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)

                    InboxSortOrderPicker(oldestFirst: $inboxOldestFirst)
                        .pickerStyle(.menu)
                }

                MySection(footer: "inboxLimitFooter") {
                    Picker("inboxLimit", selection: $autoDeleteInboxVideosLimit) {
                        ForEach(Self.inboxLimitOptions, id: \.self) { limit in
                            Text(Self.inboxLimitLabel(limit)).tag(limit)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .myNavigationTitle("inbox")
        }
    }
}

#Preview {
    InboxSettingsView()
}
