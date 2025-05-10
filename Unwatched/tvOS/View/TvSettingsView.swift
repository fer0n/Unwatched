//
//  TvSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TvSettingsView: View {
    @AppStorage(Const.markAsWatched) var markAsWatched: Bool = false

    var body: some View {
        VStack {
            Section(footer: Text("markWatchedSettingHelper")) {
                Toggle("markWatchedSetting", isOn: $markAsWatched)
            }
            Spacer()
        }
        .frame(maxWidth: 800)
    }
}

#Preview {
    TvSettingsView()
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
