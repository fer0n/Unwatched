//
//  AddVideoButton.swift
//  Unwatched
//

import SwiftUI

struct AddVideoButton: View {
    @State var avm = AddVideoViewModel()
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @State var showHelp = false

    var youtubeUrl: URL?
    var size: Double = 20

    var body: some View {
        let backgroundSize = showDropArea ? 6 * size : 2 * size

        Button {
            if isVideoUrl || isPlaylistUrl {
                Task {
                    if let youtubeUrl = youtubeUrl {
                        await avm.addUrls([youtubeUrl])
                    }
                }
            } else {
                showHelp = true
            }
        } label: {
            ZStack {
                if avm.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: avm.isSuccess == true
                            ? "checkmark"
                            : avm.isSuccess == false
                            ? "xmark"
                            : isVideoUrl || isPlaylistUrl || showDropArea
                            ? "text.insert"
                            : "circle.circle")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.semibold)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: size, height: size)
            .padding(7)
        }
        .dropDestination(for: URL.self) { items, _ in
            Task {
                await avm.addUrls(items)
            }
            return true
        } isTargeted: { targeted in
            withAnimation {
                avm.isDragOver = targeted
            }
        }
        .foregroundStyle(Color.backgroundColor)
        .background {
            Circle()
                .fill(showDropArea ? theme.color : Color.neutralAccentColor)
                .frame(width: backgroundSize, height: backgroundSize)
        }
        .popover(isPresented: $showHelp) {
            Text("dropVideosTip")
                .padding()
                .presentationCompactAdaptation(.popover)
        }
        .onAppear {
            avm.container = modelContext.container
        }
    }

    var showDropArea: Bool {
        avm.isDragOver || avm.isLoading || avm.isSuccess != nil
    }

    var isVideoUrl: Bool {
        if let url = youtubeUrl {
            return UrlService.getYoutubeIdFromUrl(url: url) != nil
        }
        return false
    }

    var isPlaylistUrl: Bool {
        if let url = youtubeUrl {
            return UrlService.getPlaylistIdFromUrl(url) != nil
        }
        return false
    }
}

#Preview {
    AddVideoButton(youtubeUrl: URL(string: "www.google.com")!)
}
