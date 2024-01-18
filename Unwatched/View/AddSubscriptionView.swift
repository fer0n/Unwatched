//
//  AddSubscriptionView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct AddSubscriptionView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State var errorMessage: String?
    @State var text: String = ""
    @State var isLoading: Bool = false
    @State var isDragOver: Bool = false
    @State var newSubs: [SubscriptionState]?

    var body: some View {
        ScrollView {
            VStack {
                headerLogo
                    .padding()
                enterTextField
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
                dropArea
                    .padding(.top)
                pasteButton
                ProgressView()
                    .opacity(isLoading ? 1 : 0)
                    .padding(.top, 5)
                ImportSubscriptionsView(subStates: newSubs)
                    .padding(.horizontal)

            }
            .padding(.horizontal)
        }
        .onDisappear {
            if newSubs != nil {
                _ = VideoService.loadNewVideosInBg(modelContext: modelContext)
            }
        }
    }

    var headerLogo: some View {
        VStack(spacing: 0) {
            Image(systemName: Const.libraryTabSF)
                .resizable()
                .frame(width: 50, height: 50)
            Text("addSubscription")
                .font(.system(size: 20, weight: .heavy))
                .submitLabel(.done)
                .onSubmit {
                    addSubscriptionFromText()
                }
                .onChange(of: text) {
                    errorMessage = nil
                }
        }
    }

    var enterTextField: some View {
        VStack {
            TextField("enterYoutubeRssUrl", text: $text)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .background(Color.grayColor)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .submitLabel(.search)
                .onSubmit {
                    addSubscriptionFromText()
                }
                .disabled(isLoading)
            Text("enterYoutubeRssUrlHelper")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading)
        }
    }

    var pasteButton: some View {
        Button {
            text = UIPasteboard.general.string ?? ""
            if !text.isEmpty {
                addSubscriptionFromText()
            }
        } label: {
            Text("paste")
                .bold()
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
                .disabled(isLoading)
        }
        .background(Color.myAccentColor)
        .foregroundColor(.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
        .padding()
    }

    var dropArea: some View {
        ZStack {
            Color.backgroundColor
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isDragOver ? Color.myBackgroundGray : .clear)
                        .stroke(isDragOver ? .clear : Color.grayColor, style: StrokeStyle(lineWidth: 2, dash: [5]))
                )

            VStack(spacing: 10) {
                Text("dropUrlsHere")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.gray)
                    .padding(.top)
                Text("dropSubscriptionHelper")
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .tint(.teal)
                    .padding(.bottom)
            }
            .padding(.horizontal)

        }
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items)
            return true
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    func addSubscriptionFromText() {
        let urls: [URL] = text.components(separatedBy: "\n").compactMap { str in
            if !str.isValidURL || str.isEmpty {
                return nil
            }
            return URL(string: str)
        }
        if urls.isEmpty {
            errorMessage = "No urls found"
        }
        addSubscription(from: urls)
    }

    func addSubscription(from urls: [URL]) {
        //        newSubs = nil
        let container = modelContext.container
        errorMessage = nil
        isLoading = true

        Task.detached {
            print("load new")
            do {
                let subs = try await SubscriptionService.addSubscriptions(from: urls, modelContainer: container)
                await MainActor.run {
                    newSubs = subs
                }
            } catch {
                print("\(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    func handleUrlDrop(_ urls: [URL]) {
        print("handleUrlDrop inbox", urls)
        addSubscription(from: urls)
    }
}

#Preview {
    AddSubscriptionView()
        .modelContainer(DataController.previewContainer)
}

// let newSubs = [
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
//    SubscriptionState(
//        url: URL(string: "https://www.youtube.com/@TomScottGo")!,
//        title: "Gamertag VR",
//        userName: "GamertagVR",
//        success: true),
//    SubscriptionState(
//        url: URL(string: "https://www.youtube.com/@TomScottGo")!,
//        userName: "veritasium",
//        error: "The request cannot be completed because you have" +
//            " exceeded your <a href=\"/youtube/v3/getting-started#quota\">quota</a>"
//    ),
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!),
//    SubscriptionState(url: URL(string: "https://www.youtube.com/@TomScottGo")!, userName: "TomScottGo")
// ]
