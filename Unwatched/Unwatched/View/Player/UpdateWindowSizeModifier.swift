//
//  UpdateWindowSizeModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct UpdateWindowSizeModifier: ViewModifier {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @Environment(PlayerManager.self) var player

    @State var viewModel = ViewModel()

    func body(content: Content) -> some View {
        content
            .onSizeChange { newSize in
                viewModel.currentSize = newSize
            }
            .onChange(of: hideControlsFullscreen, initial: true) {
                viewModel.updateWindowSize(player.videoAspectRatio, reset: true)
            }
            .onChange(of: player.videoAspectRatio) {
                viewModel.updateWindowSize(player.videoAspectRatio)
            }
    }
}

extension UpdateWindowSizeModifier {
    @Observable class ViewModel {
        @ObservationIgnored var oldSize: CGSize = .zero
        @ObservationIgnored var currentSize: CGSize = .zero

        @MainActor
        func updateWindowSize(_ aspectRatio: Double, reset: Bool = false) {
            #if os(visionOS)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

            if Const.hideControlsFullscreen.bool ?? false {
                let currentAspectRatio = currentSize.width / currentSize.height
                oldSize = currentSize
                var newWidth: Double = currentSize.width
                var newHeight: Double = currentSize.height
                if currentAspectRatio > 1 {
                    newHeight = newWidth / aspectRatio
                } else {
                    newWidth = newHeight * aspectRatio
                }

                let newSize = CGSize(width: newWidth, height: newHeight)
                let geometryPreferences = UIWindowScene.GeometryPreferences.Vision(resizingRestrictions: .uniform)
                geometryPreferences.size = newSize
                scene.requestGeometryUpdate(geometryPreferences)
            } else if reset && oldSize != .zero {
                let geometryPreferences = UIWindowScene.GeometryPreferences.Vision(resizingRestrictions: .freeform)
                geometryPreferences.size = oldSize
                scene.requestGeometryUpdate(geometryPreferences)
            }
            #endif
        }
    }
}
