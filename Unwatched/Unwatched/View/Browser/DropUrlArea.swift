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
    @Binding var avm: AddVideoViewModel
    @Binding var dropVideosTip: Bool

    let content: Content

    init(
        _ avm: Binding<AddVideoViewModel>,
        _ dropVideosTip: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self._avm = avm
        self._dropVideosTip = dropVideosTip
        self.content = content()
    }

    var showDropArea: Bool {
        avm.showDropArea || dropVideosTip
    }

    var body: some View {
        VStack {
            if showDropArea {
                Spacer()
                    .frame(height: 20)
            }
            if showDropArea {
                VStack(spacing: 0) {
                    dropAreaContent

                    if dropVideosTip {
                        Text("dropVideosTip")
                            .presentationCompactAdaptation(.popover)
                            .foregroundStyle(Color.neutralAccentColor)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
                    .frame(height: 20)
            } else {
                content
            }
        }
        .onTapGesture {
            withAnimation {
                dropVideosTip = false
            }
        }
        .contentShape(Rectangle())
        .tint(.neutralAccentColor)
        .dropDestination(for: URL.self) { items, _ in
            if dropVideosTip {
                dropVideosTip = false
            }
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
                    Image(systemName: Const.queueTopSF)
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .foregroundStyle(.white)
    }
}
