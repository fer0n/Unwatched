//
//  HideControlsSettings.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct HideControlsSettings: View {
    @AppStorage(Const.disableCaptions) var disableCaptions: Bool = false
    @AppStorage(Const.autoCaptionsOnSeekBack) var autoCaptionsOnSeekBack: Bool = false
    @AppStorage(Const.minimalPlayerUI) var minimalPlayerUI: Bool = false
    @AppStorage(Const.doubleTapSeekDuration) var doubleTapSeekDuration: Double = Const.seekSeconds
    @State var seekReloadTask: Task<Void, Never>?

    @Environment(PlayerManager.self) var player

    var body: some View {
        MySection("hideControls") {
            Toggle(isOn: $disableCaptions) {
                Text("disableCaptions")
            }
            .onChange(of: disableCaptions) {
                reloadPlayer()
            }

            Toggle(isOn: $autoCaptionsOnSeekBack) {
                Text("autoCaptionsOnSeekBack")
            }
            .onChange(of: autoCaptionsOnSeekBack) {
                reloadPlayer()
            }

            Toggle(isOn: $minimalPlayerUI) {
                Text("minimalPlayerUI")
            }
            .onChange(of: minimalPlayerUI) {
                reloadPlayer()
            }

            Stepper(value: $doubleTapSeekDuration, in: 1...120, step: 1) {
                LabeledContent("seekBy", value: "\(Int(doubleTapSeekDuration))s")
            }
            .onChange(of: doubleTapSeekDuration) { _, _ in
                seekReloadTask?.cancel()
                seekReloadTask = Task {
                    do {
                        try await Task.sleep(for: .milliseconds(800))
                        PlayerManager.reloadPlayer()
                    } catch { }
                }
            }
        }
    }

    func reloadPlayer() {
        player.hotReloadPlayer()
    }
}
