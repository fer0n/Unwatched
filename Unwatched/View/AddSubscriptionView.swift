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

    func delayedIsLoading() -> DispatchWorkItem {
        let workItem = DispatchWorkItem {
            isLoading = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        return workItem
    }

    func handleSuccess() {
        VideoService.loadNewVideosInBg(modelContext: modelContext)
        dismiss()
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
        let container = modelContext.container
        errorMessage = nil
        let workItem = delayedIsLoading()

        Task {
            print("load new")
            do {
                try await SubscriptionService.addSubscriptionsInBg(from: urls, modelContainer: container)
                DispatchQueue.main.async {
                    handleSuccess()
                }
            } catch {
                print("\(error)")
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                workItem.cancel()
                isLoading = false
            }
        }
    }

    func handleUrlDrop(_ urls: [URL]) {
        print("handleUrlDrop inbox", urls)
        addSubscription(from: urls)
    }

    var headerLogo: some View {
        VStack(spacing: 0) {
            Image(systemName: "books.vertical.fill")
                .resizable()
                .frame(width: 50, height: 50)
            Text("Add Subscription")
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
            TextField("Youtube RSS/Channel URL", text: $text)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .background(Color.grayColor)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .submitLabel(.search)
                .onSubmit {
                    addSubscriptionFromText()
                }
            Text("You can enter mutliple URLs, one per line")
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
            Text("Paste & Submit")
                .bold()
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
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
            VStack {
                Text("Drop URLs Here")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.gray)
                    .padding(5)
                Text("You can drag multiple channel URLs at the same time from your [YouTube subscriptions](https://youtube.com/feed/channels) and drop them here all at once")
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .tint(.teal)

                ProgressView()
                    .opacity(isLoading ? 1 : 0)
                    .padding(5)

            }
        }
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items)
            return true
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    var body: some View {
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
        }
        .padding(.horizontal)
    }
}

#Preview {
    AddSubscriptionView()
}
