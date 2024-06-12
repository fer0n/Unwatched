//
//  AddVideoButton.swift
//  Unwatched
//

import SwiftUI

struct AddVideoButton: View {
    @State var avm = AddVideoViewModel()
    @Environment(\.modelContext) var modelContext

    var videoUrl: URL
    var size: Double = 20

    var body: some View {
        Button {
            Task {
                await avm.addUrls([videoUrl])
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
                            : "text.insert")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.semibold)
                        .contentTransition(.symbolEffect(.replace))

                }
            }
            .frame(width: size, height: size)
            .padding(7)
        }
        .foregroundStyle(Color.backgroundColor)
        .background {
            Circle()
                .fill(Color.neutralAccentColor)
                .frame(width: 2 * size, height: 2 * size)
        }
        .onAppear {
            avm.container = modelContext.container
        }
    }
}

#Preview {
    AddVideoButton(videoUrl: URL(string: "www.google.com")!)
}
