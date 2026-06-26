//
//  PlayerTypeSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerTypeSettingsView: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)
            MyForm {
                optionSection(.youtubeEmbedded, footer: "playerTypeEmbeddedHelper")
                optionSection(.youtubeEmbeddedMinimal, footer: "playerTypeMinimalHelper")
            }
            .myNavigationTitle("playerType")
        }
    }

    func optionSection(_ type: PlayerTypeSetting, footer: LocalizedStringKey) -> some View {
        MySection(footer: footer) {
            HStack {
                Text(type.description)
                Spacer()
                if playerType == type {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { playerType = type }
        }
    }
}

#Preview {
    PlayerTypeSettingsView()
}
