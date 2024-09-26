//
//  AddVideosTutorial.swift
//  Unwatched
//

import SwiftUI
import TipKit
import UnwatchedShared

struct AddVideosButton: View {
    @Environment(NavigationManager.self) private var navManager

    var body: some View {
        Button {
            navManager.clearNavigationStack(.library)
            navManager.navigateTo(.library)
        } label: {
            Label("addVideos", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    AddVideosButton()
        .environment(NavigationManager())
        .modelContainer(DataController.previewContainer)
}
