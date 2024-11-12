//
//  SponsorBlockSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SponsorBlockSettingsView: View {
    @AppStorage(Const.mergeSponsorBlockChapters) var mergeSponsorBlockChapters: Bool = false
    @AppStorage(Const.youtubePremium) var youtubePremium: Bool = false
    @AppStorage(Const.skipSponsorSegments) var skipSponsorSegments: Bool = false

    @State var showAlert = false

    var body: some View {
        MySection("sponsorBlockSettings", footer: "sponsorBlockSettingsHelper") {
            Toggle(isOn: $mergeSponsorBlockChapters) {
                Text("sponsorBlockChapters")
            }
        }

        MySection(footer: "considerGettingYoutubePremium") {
            HStack {
                Text("youtubePremium")
                Spacer()
                Image(systemName: "checkmark")
                    .opacity(youtubePremium ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !youtubePremium {
                    showAlert = true
                } else {
                    youtubePremium = false
                    skipSponsorSegments = false
                }
            }
        }
        .actionSheet(isPresented: $showAlert) {
            ActionSheet(title: Text("youtubePremiumTitle"),
                        message: Text("considerGettingYoutubePremium"),
                        buttons: [
                            .destructive(Text("youtubePremiumConfirm"), action: {
                                youtubePremium = true
                                showAlert = false
                            }),
                            .default(Text("youtubePremiumDecline"), action: {
                                showAlert = false
                            }),
                            .cancel()
                        ])
        }

        Section(footer: Text("skipSponsorSegmentsHelper")) {
            Toggle(isOn: $skipSponsorSegments) {
                Text("skipSponsorSegments")
            }
            .disabled(!mergeSponsorBlockChapters)
        }
        .opacity(youtubePremium ? 1 : 0)
        .listRowBackground(youtubePremium ? Color.insetBackgroundColor : Color.backgroundColor)
        .animation(.default, value: youtubePremium)
    }
}

struct RightCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Image(systemName: "checkmark")
                .opacity(configuration.isOn ? 1 : 0)
        }
        //        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                configuration.isOn.toggle()
            }
        }
    }
}

#Preview {
    List {
        SponsorBlockSettingsView()
    }
}
