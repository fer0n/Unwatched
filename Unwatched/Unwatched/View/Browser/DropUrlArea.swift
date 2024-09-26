//
//  DropUrlArea.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

struct DropUrlArea<Content: View>: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(\.modelContext) var modelContext
    @State var avm = AddVideoViewModel()

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let showDropArea = avm.isDragOver || avm.isLoading || avm.isSuccess != nil

        VStack {
            if showDropArea {
                Spacer()
                    .frame(height: 40)
            }
            if showDropArea {
                dropAreaContent
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: 40)
            } else {
                content
            }
        }
        .background(showDropArea ? theme.darkColor : .clear)
        .tint(.neutralAccentColor)
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
        .sensoryFeedback(Const.sensoryFeedback, trigger: showDropArea)
        .task(id: avm.isSuccess) {
            await avm.handleSuccessChange()
        }
        .onAppear {
            avm.container = modelContext.container
        }
    }

    var dropAreaContent: some View {
        ZStack {
            let size: CGFloat = 20

            if avm.isLoading {
                ProgressView()
            } else if avm.isSuccess == true {
                Image(systemName: "checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .accessibilityLabel("success")
            } else if avm.isSuccess == false {
                Image(systemName: Const.clearNoFillSF)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .accessibilityLabel("failed")
            } else {
                VStack {
                    Image(systemName: Const.queueTagSF)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("dropVideoUrlsHere")
                        .fontWeight(.medium)
                }
            }
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    DropUrlArea {
        Text(verbatim: "hello")
    }
    .modelContainer(DataController.previewContainer)
}
